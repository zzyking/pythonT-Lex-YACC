/* YACC grammar for Python to C conversion */
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define MAX_SYMBOLS 1000

extern int yylex();
extern int line_num;
extern char* yytext;
extern FILE* yyin;
FILE* outfile;

void yyerror(const char* s);
int indent_level = 0;
int in_main = 0;

/* Global variables to store expression values */
char current_expr_value[1024];
char current_expr_type[64];
char function_params[1024];
char function_args[1024];

/* Constructing Symbol Table */
struct symbol {
    char name[256];
    char type[64];
};
struct symbol symbol_table[MAX_SYMBOLS];
int symbol_count = 0;

void add_symbol(char *name, char *type) {
    // 检查是否已存在
    for (int i = 0; i < symbol_count; i++) {
        if (strcmp(symbol_table[i].name, name) == 0) {
            strcpy(symbol_table[i].type, type);
            return;
        }
    }
    // 添加新符号
    strcpy(symbol_table[symbol_count].name, name);
    strcpy(symbol_table[symbol_count].type, type);
    symbol_count++;
}

char* get_symbol_type(char *name) {
    for (int i = 0; i < symbol_count; i++) {
        if (strcmp(symbol_table[i].name, name) == 0) {
            return symbol_table[i].type;
        }
    }
    return "unknown";
}

/* Class System */
struct ClassNode {
    char name[256];
    struct symbol members[64];
    int member_count;
};

struct ClassNode class_table[MAX_SYMBOLS];
int class_count = 0;
char *current_class = NULL;

void add_class(char *name) {
    strcpy(class_table[class_count].name, name);
    class_table[class_count++].member_count = 0;
}

void add_class_member(char *class_name, char *member_name, char *type) {
    for (int i = 0; i < class_count; i++) {
        if (strcmp(class_table[i].name, class_name) == 0) {
            struct symbol new_member;
            strcpy(new_member.name, member_name);
            strcpy(new_member.type, type);
            class_table[i].members[class_table[i].member_count++] = new_member;
            return;
        }
    }
    fprintf(stderr, "Class %s not found for member %s\n", class_name, member_name);
}

/* Helper functions for code generation */
void start_block() {
    fprintf(outfile, "{\n");
    indent_level++;
}

void end_block() {
    indent_level--;
    for (int i = 0; i < indent_level; i++) fprintf(outfile, "    ");
    fprintf(outfile, "}\n");
}

void print_indent() {
    for (int i = 0; i < indent_level; i++) fprintf(outfile, "    ");
}

char* get_c_type(char* py_type) {
    if (strcmp(py_type, "int") == 0) return "int";
    if (strcmp(py_type, "float") == 0) return "double";
    if (strcmp(py_type, "str") == 0) return "char*";
    if (strcmp(py_type, "bool") == 0) return "bool";
    if (strcmp(py_type, "list") == 0) return "int";
    return py_type;
}

void replace_dot_with_underscore(char *dest, const char *src) {
    while (*src) {
        if (*src == '.') {
            *dest = '_';
        } else {
            *dest = *src;
        }
        src++;
        dest++;
    }
    *dest = '\0'; // 结尾加 null terminator
}

void print_list_declaration(char* var_name, char* elements) {
    print_indent();
    fprintf(outfile, "int %s[] = %s;\n", var_name, elements);
    print_indent();
    fprintf(outfile, "int %s_size = sizeof(%s) / sizeof(%s[0]);\n", var_name, var_name, var_name);
}
%}

%union {
    int int_val;
    double float_val;
    int bool_val;
    char str_val[1024];
    char id[256];
    int indent_val;
    struct {
        char value[1024];
        char type[64];
    } expr;
    struct {
        char name[256];
        char type[64];
    } param;
}

%token <int_val> INT
%token <float_val> FLOAT
%token <bool_val> BOOL
%token <str_val> STRING TYPE
%token <id> ID

%token IF ELSE ELIF WHILE FOR DEF CLASS RETURN PRINT IN RANGE IMPORT APPEND
%token COLON LPAREN RPAREN LBRACKET RBRACKET
%token ASSIGN EQ NEQ LT GT LTE GTE
%token PLUS MINUS TIMES DIVIDE MOD
%token COMMA DOT AND OR NOT NONE ARROW

%type <expr> expression list_literal function_call argument_list list_elements class_member
%type <param> typed_parameter
%type <str_val> parameter_list

%left OR
%left AND
%left EQ NEQ
%left LT GT LTE GTE
%left PLUS MINUS
%left TIMES DIVIDE MOD
%right NOT

%start program

%%

program:{
          /* Write C file header */
          fprintf(outfile, "#include <stdio.h>\n");
          fprintf(outfile, "#include <stdlib.h>\n");
          fprintf(outfile, "#include <string.h>\n");
          fprintf(outfile, "#include <stdbool.h>\n\n");
        } statements
        ;

statements: global_statements {
            if (!in_main) {
                fprintf(outfile, "int main() {\n");
                indent_level++;
                in_main = 1;
            }
          }
          local_statements {
            if (in_main) {
                print_indent();
                fprintf(outfile, "return 0;\n");
                fprintf(outfile, "}\n");
                in_main = 0;
            }
          }
          ;

global_statements: /* empty */
                 | global_statements global_statement
                 ;

local_statements: /* empty */
                | local_statements local_statement
                ;

global_statement: function_def
                  | class_def
                  | import_statement
                  ;

local_statement: if_statement
               | while_statement
               | for_statement
               | assignment_statement
               | typed_assignment_statement
               | class_assignment_statement
               | function_call_statement
               | method_call_statement
               | print_statement
               ;

typed_assignment_statement: ID COLON TYPE ASSIGN expression {
                              if (strcmp($3, "list") == 0) {
                                  add_symbol($1, "list");
                                  print_list_declaration($1, $5.value);
                              } else {
                                  add_symbol($1, $3);
                                  print_indent();
                                  fprintf(outfile, "%s %s = %s;\n", get_c_type($3), $1, $5.value);
                              }
                            }
                          ;

class_assignment_statement: ID COLON ID ASSIGN ID LPAREN RPAREN {
                              for (int i = 0; i < class_count; i++) {
                                  if (strcmp(class_table[i].name, $3) == 0) {
                                      add_symbol($1, "class_var");
                                      for (int j = 0; j < class_table[i].member_count; j++) {
                                          char* member_type = class_table[i].members[j].type;
                                          char* member_name = class_table[i].members[j].name;
                                          char symbol_name[512];
                                          sprintf(symbol_name, "%s.%s", $1, member_name);
                                          add_symbol(symbol_name, member_type);
                                      }
                                  }
                              }
                              print_indent();
                              fprintf(outfile, "%s %s;\n", $3, $1);
                            }

if_statement: IF expression COLON {
                print_indent();
                fprintf(outfile, "if (%s)", $2.value);
                start_block();
              }
              block {
                end_block();
              }
              elif_blocks
              else_block
            ;

elif_blocks: /* empty */
           | ELIF expression COLON {
                print_indent();
                fprintf(outfile, "else if (%s)", $2.value);
                start_block();
             }
             block {
                end_block();
             }
             elif_blocks
           ;

else_block: /* empty */
          | ELSE COLON {
                print_indent();
                fprintf(outfile, "else");
                start_block();
            }
            block {
                end_block();
            }
          ;

for_else_block: /* empty */
              | ELSE COLON {
                  print_indent();
                  start_block();
              }
              block {
                  end_block();
              }
          ;

while_statement: WHILE expression COLON {
                   print_indent();
                   fprintf(outfile, "while (%s)", $2.value);
                   start_block();
                 }
                 block {
                   end_block();
                 }
               ;

for_statement: FOR ID IN RANGE LPAREN expression RPAREN COLON {
                 print_indent();
                 fprintf(outfile, "for (int %s = 0; %s < %s; %s++)", $2, $2, $6.value, $2);
                 start_block();
               }
               block {
                 end_block();
               }
               for_else_block
               | FOR ID IN RANGE LPAREN expression COMMA expression RPAREN COLON {
                 print_indent();
                 fprintf(outfile, "for (int %s = %s; %s < %s; %s++)", $2, $6.value, $2, $8.value, $2);
                 start_block();
               }
               block {
                 end_block();
               }
               for_else_block
               | FOR ID IN RANGE LPAREN expression COMMA expression COMMA expression RPAREN COLON {
                 print_indent();
                 fprintf(outfile, "for (int %s = %s; %s < %s; %s += %s)", $2, $6.value, $2, $8.value, $2, $10.value);
                 start_block();
               }
               block {
                 end_block();
               }
               for_else_block
               | FOR ID IN list_literal COLON {
                 print_indent();
                 fprintf(outfile, "int temp_array[] = %s;\n", $4.value);
                 print_indent();
                 fprintf(outfile, "int temp_size = sizeof(temp_array) / sizeof(temp_array[0]);\n");
                 print_indent();
                 fprintf(outfile, "for (int temp_i = 0; temp_i < temp_size; temp_i++)");
                 start_block();
                 print_indent();
                 fprintf(outfile, "int %s = temp_array[temp_i];\n", $2);
               }
               block {
                 end_block();
               }
               for_else_block    
             ;

assignment_statement: ID ASSIGN expression {
                        print_indent();
                        if(strcmp(get_symbol_type($1), "list") == 0) {
                            fprintf(outfile, "%s = %s;\n", $1, $3.value);
                            print_indent();
                            fprintf(outfile, "int %s_size = sizeof(%s) / sizeof(%s[0]);\n", $1, $1, $1);
                        }else{
                            fprintf(outfile, "%s = %s;\n", $1, $3.value);
                        }
                      }
                      | ID DOT ID ASSIGN expression {
                        print_indent();
                        char value[512];
                        sprintf(value, "%s.%s", $1, $3);
                        if (strcmp(get_symbol_type(value), "list")==0) {
                            fprintf(outfile, "int arr_%s[] = %s;\n", $1, $5.value);
                            print_indent();
                            fprintf(outfile, "%s.%s_size = sizeof(arr_%s) / sizeof(arr_%s[0]);\n", $1, $3, $1, $1);
                            print_indent();
                            fprintf(outfile, "for (int i = 0; i < %s.%s_size; i++) {\n", $1, $3);
                            indent_level++;
                            print_indent();
                            fprintf(outfile, "%s.%s[i] = arr_%s[i];\n", $1, $3, $1);
                            indent_level--;
                            print_indent();
                            fprintf(outfile, "}\n");
                        } else {
                            fprintf(outfile, "%s = %s;\n", value, $5.value);
                        }
                      }
                      | ID COLON ID ASSIGN expression {
                          for (int i = 0; i < class_count; i++) {
                              if (strcmp(class_table[i].name, $3) == 0) {
                                  add_symbol($1, "class_var");
                                  for (int j = 0; j < class_table[i].member_count; j++) {
                                      char* member_type = class_table[i].members[j].type;
                                      char* member_name = class_table[i].members[j].name;
                                      char symbol_name[512];
                                      sprintf(symbol_name, "%s.%s", $1, member_name);
                                      add_symbol(symbol_name, member_type);
                                  }
                              }
                          }
                          print_indent();
                          fprintf(outfile, "%s %s = %s;\n", $3, $1, $5.value);
                      }
                    ;

function_def: DEF ID LPAREN parameter_list RPAREN COLON {
                fprintf(outfile, "void %s(%s)", $2, $4);
                start_block();
              }
              block {
                end_block();
              }
            | DEF ID LPAREN parameter_list RPAREN ARROW TYPE COLON {
                fprintf(outfile, "%s %s(%s)", get_c_type($7), $2, $4);
                start_block();
              }
              blocks return_statement {
                end_block();
              }
            | DEF ID LPAREN parameter_list RPAREN ARROW ID COLON {
                fprintf(outfile, "%s %s(%s)", get_c_type($7), $2, $4);
                start_block();
              }
              blocks return_statement {
                end_block();
              }
            ;

class_def: CLASS ID COLON {
              add_class($2);
              current_class = strdup($2);
              fprintf(outfile, "typedef struct");
              start_block();
          }
          class_member {
            indent_level--;
            fprintf(outfile, "}%s;\n\n", $2);
          }
         ;

class_member: ID COLON TYPE {
                  print_indent();
                  add_class_member(current_class, $1, $3);
                  if (strcmp($3, "list") == 0) {
                      fprintf(outfile, "int %s[512];\n", $1);
                      print_indent();
                      fprintf(outfile, "int %s_size;\n", $1);
                  } else {
                      fprintf(outfile, "%s %s;\n", get_c_type($3), $1);
                  }
                }
              ;

parameter_list: /* empty */ {
                  strcpy($$, "");
                }
              | typed_parameter {
                  sprintf($$, "%s %s", get_c_type($1.type), $1.name);
                }
              | parameter_list COMMA typed_parameter {
                  if (strlen($1) > 0) {
                      sprintf($$, "%s, %s %s", $1, get_c_type($3.type), $3.name);
                  } else {
                      sprintf($$, "%s %s", get_c_type($3.type), $3.name);
                  }
                }
              ;

typed_parameter: ID COLON TYPE {
                   strcpy($$.name, $1);
                   strcpy($$.type, $3);
                 }
                 | ID COLON ID {
                    strcpy($$.name, $1);
                    strcpy($$.type, $3);
                 }
               ;

function_call_statement: ID LPAREN argument_list RPAREN {
                            print_indent();
                            fprintf(outfile, "%s(%s);\n", $1, $3.value);
                          }
                       ;

method_call_statement: ID DOT ID DOT ID LPAREN argument_list RPAREN {
                         print_indent();
                         fprintf(outfile, "%s.%s.%s(%s);\n", $1, $3, $5, $7.value);
                       }
                       | ID DOT ID DOT APPEND LPAREN argument_list RPAREN {
                         print_indent();
                         fprintf(outfile, "%s.%s[%s.%s_size++] = %s;\n", $1, $3, $1, $3, $7.value);
                       }
                       | ID DOT ID LPAREN argument_list RPAREN {
                         print_indent();
                         fprintf(outfile, "%s.%s(%s);\n", $1, $3, $5.value);
                       }
                       | ID DOT APPEND LPAREN argument_list RPAREN {
                         print_indent();
                         fprintf(outfile, "%s[%s_size++] = %s;\n", $1, $1, $5.value);
                       }
                     ;

argument_list: /* empty */ {
                 strcpy($$.value, "");
               }
             | expression {
                 strcpy($$.value, $1.value);
               }
             | argument_list COMMA expression {
                 if (strlen($1.value) > 0) {
                     sprintf($$.value, "%s, %s", $1.value, $3.value);
                 } else {
                     strcpy($$.value, $3.value);
                 }
               }
             ;

return_statement: RETURN {
                    print_indent();
                    fprintf(outfile, "return;\n");
                  }
                | RETURN expression {
                    print_indent();
                    fprintf(outfile, "return %s;\n", $2.value);
                  }
                ;

print_statement: PRINT LPAREN print_args RPAREN {
                   print_indent();
                   fprintf(outfile, "printf(\"\\n\");\n");
                 }
               ;

print_args: print_arg {}
          | print_args {
              print_indent();
              fprintf(outfile, "printf(\" \");\n");
            }
            COMMA print_arg 
          ;

print_arg: STRING {
             print_indent();
             char *str = $1;
             if (str[0] == '"' || str[0] == '\'') {
                 str++;
                 str[strlen(str)-1] = '\0';
             }
             fprintf(outfile, "printf(\"%s\");\n", str);
           }
         | expression {
             if (strcmp($1.type, "list") == 0) {
                 /* 处理列表输出 */
                 print_indent();
                 fprintf(outfile, "printf(\"[\");\n");
                 print_indent();
                 fprintf(outfile, "for (int i = 0; i < %s_size; i++) {\n", $1);
                 indent_level++;
                 print_indent();
                 fprintf(outfile, "if (i > 0) printf(\", \");\n");
                 print_indent();
                 fprintf(outfile, "printf(\"%%d\", %s[i]);\n", $1);
                 indent_level--;
                 print_indent();
                 fprintf(outfile, "}\n");
                 print_indent();
                 fprintf(outfile, "printf(\"]\");\n");
             } else {
                 print_indent();
                 char* actual_type = get_symbol_type($1.value);
                 
                 if (strcmp(actual_type, "int") == 0) {
                     fprintf(outfile, "printf(\"%%d\", %s);\n", $1.value);
                 } else if (strcmp(actual_type, "float") == 0) {
                     fprintf(outfile, "printf(\"%%g\", %s);\n", $1.value);
                 } else if (strcmp(actual_type, "str") == 0) {
                     fprintf(outfile, "printf(\"%%s\", %s);\n", $1.value);
                 } else {
                     fprintf(outfile, "printf(\"%%d\", %s);\n", $1.value);
                 }
             }
           }
         ;

import_statement: IMPORT ID {
                    print_indent();
                    fprintf(outfile, "#include \"%s.h\"\n", $2);
                  }
                ;

blocks: /* empty */
     | blocks block
     ;

block: /* empty */
     | local_statement
     ;

list_literal: LBRACKET list_elements RBRACKET {
                sprintf($$.value, "{%s}", $2.value);
                strcpy($$.type, $2.type);
              }
            ;

list_elements: /* empty */ {
                strcpy($$.value, "");
                strcpy($$.type, "list");
              }
             | expression {
                sprintf($$.value, "%s", $1.value);
                strcpy($$.type, "list");
              }
             | list_elements COMMA expression {
                if (strlen($1.value) > 0) {
                    sprintf($$.value, "%s, %s", $1.value, $3.value);
                } else {
                    sprintf($$.value, "%s", $3.value);
                }
                strcpy($$.type, "list");
             }
             ;


expression:INT { 
              sprintf($$.value, "%d", $1);
              strcpy($$.type, "int");
            }
          | FLOAT { 
              sprintf($$.value, "%g", $1);
              strcpy($$.type, "float");
            }
          | BOOL { 
              sprintf($$.value, "%s", $1 ? "true" : "false");
              strcpy($$.type, "bool");
            }
          | STRING { 
              strcpy($$.value, $1);
              strcpy($$.type, "str");
            }
          | ID { 
              strcpy($$.value, $1);
              char* type = get_symbol_type($1);
              if (strcmp(type, "unknown") == 0) {
                  strcpy($$.type, "int");
              } else {
                  strcpy($$.type, type);
              }
            }
          | ID LBRACKET expression RBRACKET {
              char value[512];
              sprintf(value, "%s[%s]", $1, $3.value);
              strcpy($$.value, value);
              char* type = get_symbol_type($1);
              if (strcmp(type, "list") == 0) {
                  strcpy($$.type, "int");
              } else {
                  strcpy($$.type, type);
              }
            }
          | ID DOT ID {
              char value[512];
              sprintf(value, "%s.%s", $1, $3);
              strcpy($$.value, value);
              strcpy($$.type, get_symbol_type(value));
            }
          | ID DOT ID LBRACKET expression RBRACKET {
              char value[512];
              sprintf(value, "%s.%s[%s]", $1, $3, $5.value);
              strcpy($$.value, value);
              strcpy($$.type, get_symbol_type(value));
            }
          | list_literal {
              strcpy($$.value, $1.value);
              strcpy($$.type, "list");
          }
          | LPAREN expression RPAREN {
              strcpy($$.value, $2.value);
              strcpy($$.type, $2.type);
            }
          | expression PLUS expression {
              sprintf($$.value, "(%s + %s)", $1.value, $3.value);
              strcpy($$.type, "int");
            }
          | expression MINUS expression {
              sprintf($$.value, "(%s - %s)", $1.value, $3.value);
              strcpy($$.type, "int");
            }
          | expression TIMES expression {
              sprintf($$.value, "(%s * %s)", $1.value, $3.value);
              strcpy($$.type, "int");
            }
          | expression DIVIDE expression {
              sprintf($$.value, "(%s / %s)", $1.value, $3.value);
              strcpy($$.type, "int");
            }
          | expression MOD expression {
              sprintf($$.value, "(%s %% %s)", $1.value, $3.value);
              strcpy($$.type, "int");
            }
          | expression EQ expression {
              sprintf($$.value, "(%s == %s)", $1.value, $3.value);
              strcpy($$.type, "bool");
            }
          | expression NEQ expression {
              sprintf($$.value, "(%s != %s)", $1.value, $3.value);
              strcpy($$.type, "bool");
            }
          | expression LT expression {
              sprintf($$.value, "(%s < %s)", $1.value, $3.value);
              strcpy($$.type, "bool");
            }
          | expression GT expression {
              sprintf($$.value, "(%s > %s)", $1.value, $3.value);
              strcpy($$.type, "bool");
            }
          | expression LTE expression {
              sprintf($$.value, "(%s <= %s)", $1.value, $3.value);
              strcpy($$.type, "bool");
            }
          | expression GTE expression {
              sprintf($$.value, "(%s >= %s)", $1.value, $3.value);
              strcpy($$.type, "bool");
            }
          | NOT expression {
              sprintf($$.value, "(!%s)", $2.value);
              strcpy($$.type, "bool");
            }
          | function_call
          ;

function_call: ID LPAREN argument_list RPAREN {
                 sprintf($$.value, "%s(%s)", $1, $3.value);
                 strcpy($$.type, "function");
               }
             ;

%%

void yyerror(const char* s) {
    fprintf(stderr, "Error on line %d: %s\n", line_num, s);
    exit(1);
}

int main(int argc, char* argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s input_file\n", argv[0]);
        return 1;
    }

    yyin = fopen(argv[1], "r");
    if (!yyin) {
        fprintf(stderr, "Cannot open input file %s\n", argv[1]);
        return 1;
    }
    
    char outfile_name[256];
    strcpy(outfile_name, argv[1]);
    char* dot = strrchr(outfile_name, '.');
    if (dot) {
        strcpy(dot, ".c");
    } else {
        strcat(outfile_name, ".c");
    }
    
    outfile = fopen(outfile_name, "w");
    if (!outfile) {
        fprintf(stderr, "Cannot open output file %s\n", outfile_name);
        fclose(yyin);
        return 1;
    }

    yyparse();
    
    
    fclose(yyin);
    fclose(outfile);
    return 0;
}
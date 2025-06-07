%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int yylex();
extern int line_num;
extern char* yytext;
extern FILE* yyin;
FILE* outfile;

void yyerror(const char* s);
int indent_level = 0;
int in_main = 0;

/* Helper functions for code generation */
void start_block() {
    fprintf(outfile, " {\n");
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

const char* get_c_type(char* py_type) {
    if (strcmp(py_type, "int") == 0) return "int";
    if (strcmp(py_type, "float") == 0) return "double";
    if (strcmp(py_type, "str") == 0) return "char*";
    if (strcmp(py_type, "bool") == 0) return "bool";
    if (strcmp(py_type, "list") == 0) return "int";
    return "auto";
}

void print_list_declaration(char* var_name, char* elements) {
    print_indent();
    fprintf(outfile, "int %s[] = %s;\n", var_name, elements);
    print_indent();
    fprintf(outfile, "int %s_size = sizeof(%s) / sizeof(%s[0]);\n", var_name, var_name, var_name);
}


void set_expr_value(char* value, char* type) {
    strcpy(current_expr_value, value);
    strcpy(current_expr_type, type);
}
%}

%union{
    int int_val;
    double float_val;
    int bool_val;
    char* str_val;
    struct {
        char* valuel
        char* type;
    } expr;
}

%token <int_val> INT
%token <float_val> FLOAT
%token <bool_val> BOOL
%token <str_val> STRING TYPE ID
%token IF ELSE ELIF WHILE FOR DEF CLASS RETURN PRINT IN RANGE IMPORT APPEND
%token COLON LPAREN RPAREN LBRACKET RBRACKET
%token ASSIGN EQ NEQ LT GT LTE GTE
%token PLUS MINUS TIMES DIVIDE MOD
%token COMMA DOT AND OR NOT NONE ARROW
%type <expr> expression term factor
%type <str_val> 

%left OR
%left AND
%left EQ NEQ
%left LT GT LTE GTE
%left PLUS MINUS
%left TIMES DIVIDE MOD
%right NOT

%start program

%%

program: statements ;

    
    

%%

%{
    #include <stdio.h>
    #include <stdlib.h>
    #include <string.h>
    #include "y.tab.h"
    
    extern int yylineno;
    extern FILE *yyin;
    extern int last_token_was_newline;
    
    void yyerror(const char *s);
    int yylex(void);
    %}

    %union{
        char* text;
    }
    
    //token示例 (需补充)
    %token ENDMARKER INDENT DEDENT NEWLINE
    %token <text> IDENTIFIER NUMBER STR TYPE
    %token AND OR NOT APPEND PRINT PASS IF ELIF ELSE RETURN RANGE BREAK CONTINUE DEF CLASS FOR IN TRUE FALSE
    %token ADD_OP MUL_OP REL_OP ASSIGN_OP
    %token ARROW
    %token INT FLOAT BOOL LIST
    %left OR
    %left AND
    %nonassoc REL_OP
    %left ADD_OP
    %left MUL_OP
    %type <text> type 
    
    %%

    //语法结构示例（需补充)
    file    : statements ENDMARKER
            { printf("reduce by file -> statements ENDMARKER\n"); printf("accept"); YYACCEPT; }
        ;
    statements  : statements statement
            { printf("reduce by statements -> statements statement\n"); }
        |
            { printf("reduce by statements -> empty\n"); }
        ;
    statement   : compound_stmt
            { printf("reduce by statement -> compound_stmt\n"); }
        | simple_stmts
            { printf("reduce by statement -> simple_stmts\n"); }
        ;
    compound_stmt   : if_stmt
            { printf("reduce by compound_stmt -> if_stmt\n"); }
        ;
    simple_stmts    : simple_stmt_list NEWLINE
            { printf("reduce by simple_stmts -> simple_stmt_list NEWLINE\n"); }
        ;
    simple_stmt_list    : simple_stmt
            { printf("reduce by simple_stmt_list -> simple_stmt\n"); }
        | simple_stmt_list ';' simple_stmt
            { printf("reduce by simple_stmt_list -> simple_stmt_list ; simple_stmt\n"); }
        ;
    simple_stmt : assignment
            { printf("reduce by simple_stmt -> assignment\n"); }
        | print_stmt
            { printf("reduce by simple_stmt -> print_stmt\n"); }
        | method_call
            { printf("reduce by simple_stmt -> method_call\n"); }
        | declaration
            { printf("reduce by simple_stmt -> declaration\n"); }
        | PASS
            { printf("reduce by simple_stmt -> PASS\n"); }
        ;
    expression  : or_expr
            { printf("reduce by expression -> or_expr\n"); }
        ;
    or_expr     : and_expr
            { printf("reduce by or_expr -> and_expr\n"); }
        | or_expr OR and_expr
            { printf("reduce by or_expr -> or_expr OR and_expr\n"); }
        ;
    and_expr    : compare_expr
            { printf("reduce by and_expr -> compare_expr\n"); }
        | and_expr AND compare_expr
            { printf("reduce by and_expr -> and_expr AND compare_expr\n"); }
        ;
    compare_expr    : arithmetic_expr
            { printf("reduce by compare_expr -> arithmetic_expr\n"); }
        | arithmetic_expr REL_OP arithmetic_expr
            { printf("reduce by compare_expr -> arithmetic_expr REL_OP arithmetic_expr\n"); }
        ;
    arithmetic_expr : term
            { printf("reduce by arithmetic_expr -> term\n"); }
        | arithmetic_expr ADD_OP term
            { printf("reduce by arithmetic_expr -> arithmetic_expr ADD_OP term\n"); }
        ;
    term    : factor
            { printf("reduce by term -> factor\n"); }
        | term MUL_OP factor
            { printf("reduce by term -> term MUL_OP factor\n"); }
        ;
    factor  : '(' expression ')'
            { printf("reduce by factor -> ( expression )\n"); }
        | NUMBER
            { printf("reduce by factor -> NUMBER\n"); }
        | list
            { printf("reduce by factor -> list\n"); }
        | ADD_OP factor
            { printf("reduce by factor -> ADD_OP factor\n"); }
        | target
            { printf("reduce by factor -> target\n"); }
        ;
    assignment  : target ASSIGN_OP expression
            { printf("reduce by assignment -> target ASSIGN_OP expression\n"); }
        | target '=' expression
            { printf("reduce by assignment -> target ASSIGN_OP expression\n"); }
        ;
    print_stmt  : PRINT '(' args ')'
            { printf("reduce by print_stmt -> PRINT ( args )\n"); }
        ;
    args    : arg
            { printf("reduce by args -> arg\n"); }
        | args ',' arg
            { printf("reduce by args -> args , arg\n"); }
        ;
    arg : STR
            { printf("reduce by arg -> STR\n"); }
        | expression
            { printf("reduce by arg -> expression\n"); }
        ;
    declaration : target ':' type '=' expression
            { printf("reduce by declaration -> target : TYPE = expression\n"); }
        | target ':' type
            { printf("reduce by declaration -> target : TYPE\n"); }
        ;
    target  : IDENTIFIER
            { printf("reduce by target -> IDENTIFIER\n"); }
        | target '.' IDENTIFIER
            { printf("reduce by target -> target . IDENTIFIER\n"); }
        | target '[' expression ']'
            { printf("reduce by target -> target [ expression ]\n"); }
        ;
    if_stmt : IF expression ':' block elif_stmt
            { printf("reduce by if_stmt -> IF expression : block elif_stmt\n"); }
        | IF expression ':' block else_block
            { printf("reduce by if_stmt -> IF expression : block else_block\n"); }
        ;
    elif_stmt   : ELIF expression ':' block elif_stmt
            { printf("reduce by elif_stmt -> ELIF expression : block elif_stmt\n"); }
        | ELIF expression ':' block else_block
            { printf("reduce by elif_stmt -> ELIF expression : block else_block\n"); }
        ;
    else_block  : ELSE ':' block
            { printf("reduce by else_block -> ELSE : block\n"); }
        | /* empty */
            { printf("reduce by else_block -> empty\n"); }
        ;
    block   : NEWLINE INDENT statements DEDENT
            { printf("reduce by block -> NEWLINE INDENT statements DEDENT\n"); }
        | simple_stmts
            { printf("reduce by block -> simple_stmts\n"); }
        ;
    list    : '[' list_elements ']'
            { printf("reduce by list -> [ list_elements ]\n"); }
        ;
    list_elements   : /* empty */
            { printf("reduce by list_elements -> empty\n"); }
        | expression_list
            { printf("reduce by list_elements -> expression_list\n"); }
        ;
    expression_list : expression
            { printf("reduce by expression_list -> expression\n"); }
        | expression_list ',' expression
            { printf("reduce by expression_list -> expression_list , expression\n"); }
        ;
    method_call : target '.' APPEND '(' expression ')'
            { printf("reduce by method_call -> target . APPEND ( expression )\n"); }
        ;
    type    : TYPE   
            { printf("reduce by TYPE -> %s\n", $1); $$ = $1; }
        ;

    %%
    
    void yyerror(const char *s) {
        fprintf(stderr, "%d %s\n", yylineno, s);
    }
    
int main(int argc, char **argv) {  

    if (argc > 1) {  
        if (!(yyin = fopen(argv[1], "r"))) {  
            perror(argv[1]);  
            return 1;  
        }  
    }  
    yyparse();
    return 0;  
}
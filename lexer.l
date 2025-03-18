%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int keyword_count = 0;       // 关键字数量  
int identifier_count = 0;    // 标识符数量  
int operator_count = 0;      // 操作符数量  
int delimiter_count = 0;     // 分隔符数量  
int string_count = 0;        // 字符串数量  
int number_count = 0;        // 数字数量
int comment_count = 0;        // 注释数量
int error_count = 0;         // 错误数量   
int line_num = 1;
int full_comment = 0;

typedef struct {
    int stack[100];
    int top;
}IndentStack;

IndentStack indent_stack;

void indent_stack_init(IndentStack *s) {
    s->top = -1;
}

void indent_stack_push(IndentStack *s, int value) {
    s->stack[++s->top] = value;
}

int indent_stack_pop(IndentStack *s) {
    return s->stack[s->top--];
}

int indent_stack_peek(IndentStack *s) {
    return s->stack[s->top];
}

void handle_indent_level(int current) {
    if (full_comment){ full_comment=0; return; }
    int top = indent_stack_peek(&indent_stack);
    if (current == top) {
        return;
    } else if (current > top) {
        printf("%d <INDENT>\n", line_num);
        indent_stack_push(&indent_stack, current);
    } else {
        int found = 0;
        while (indent_stack_peek(&indent_stack) > current) {
            indent_stack_pop(&indent_stack);
            printf("%d <DEDENT>\n", line_num);
            if (indent_stack_peek(&indent_stack) == current) {
                found = 1;
                break;
            }
        }
        if (!found) {
            printf("%d <ERROR,indentation level does not match (fatal error and parse terminates)>\n", line_num);
            exit(1);
        }
    }
}

%}

KEYWORD    "int"|"float"|"list"|"bool"|"append"|"return"|"print"|"range"|"pass"|"break"|"continue"|"def"|"if"|"elif"|"else"|"class"|"for"|"in"
DIGIT    [0-9]
LETTER    [a-zA-Z]
ID    (_|{LETTER})({LETTER}|_|{DIGIT})*
OPERATOR    "+"|"-"|"*"|"/"|"%"|"=="|"!="|">"|"<"|">="|"<="|"and"|"or"|"not"|"="|"+="|"-="|"*="|"/="|"%="|"<<="|">>="|"&="|"^="|"|="|"."|"->"
DELIMITER    [;,?:()\[\]]
SYMBOL    "!"|"@"|"#"|"$"|"%"|"^"|"&"|"*"|"("|")"|"-"|"_"|"+"|"="|"{"|"["|"]"|"}"|";"|":"|"'"|"<"|","|">"|"."|"?"|"/"|" "
DIGITS    {DIGIT}+
OPTIONAL_FRAC    (\.{DIGITS}|\.)?
OPTIONAL_EXP    (("e"|"E")("+"|"-")?{DIGITS})?
NUMBER    {DIGITS}?{OPTIONAL_FRAC}{OPTIONAL_EXP}
COMMENT   #.*
STR    \"({LETTER}|{DIGIT}|{SYMBOL})*\"
UNSTR    \"({LETTER}|{DIGIT}|{SYMBOL})*

%x INDENT_PROCESSING

%%         
{STR}    {string_count++; printf("%d <STRING,%s>\n", line_num, yytext);}

{UNSTR}    {printf("%d <ERROR,unterminated string literal:%s>\n", line_num, yytext); error_count++;}

<INDENT_PROCESSING>^[ \t]*{COMMENT}    {comment_count++; printf("%d <COMMENT>\n", line_num); full_comment=1;}

<INDENT_PROCESSING>^[ \t]+  { handle_indent_level(yyleng);
                              BEGIN(INITIAL);
                            }

<INDENT_PROCESSING>.|\n     { yyless(0);    
                              handle_indent_level(0);
                              BEGIN(INITIAL);
                            }
       
\n    { line_num++;
        printf("%d <NEWLINE>\n", line_num - 1);
        BEGIN(INDENT_PROCESSING);
      }
{COMMENT}    { comment_count++; printf("%d <COMMENT>\n", line_num); } 
{KEYWORD}    { keyword_count++; printf("%d <KEYWORD,%s>\n", line_num, yytext); }
{ID}    { identifier_count++; printf("%d <IDENTIFIER,%s>\n", line_num, yytext); }
{OPERATOR}    { operator_count++; printf("%d <OPERATOR,%s>\n", line_num, yytext); }
{DELIMITER}    { delimiter_count++; printf("%d <DELIMITER,%s>\n", line_num, yytext); }
{NUMBER}    { number_count++; printf("%d <NUMBER,%s>\n", line_num, yytext); }
^[ \t]+    {}
.    {}

%%
int yywrap() { return 1; }  
int main(int argc, char **argv) {  
    indent_stack_init(&indent_stack);
    indent_stack_push(&indent_stack, 0); 
    if (argc > 1) {  
        if (!(yyin = fopen(argv[1], "r"))) {  
            perror(argv[1]);  
            return 1;  
        }  
    }
    BEGIN(INDENT_PROCESSING);
    yylex();
    printf("%d <NEWLINE>\n", line_num++);
    while(indent_stack_peek(&indent_stack) > 0){
        printf("%d <DEDENT>\n", line_num);
        indent_stack_pop(&indent_stack);
    }
    printf("%d <ENDMARKER>\n", line_num);
    printf("%d\n%d %d %d %d %d %d %d\n%d", line_num, keyword_count, identifier_count, operator_count, delimiter_count, string_count, number_count, comment_count, error_count);
    return 0;  
}

%{
    #include "y.tab.h"
    #include <stdlib.h>
    #include <string.h>
    
    void yyerror(const char *s);

    int last_token_was_newline = 0;
    int curr = 0;
    int indent_stack[100];
    int top = 0;
%}

Digit             [0-9]
Digits            {Digit}+
OPTIONAL_FRAC     (\.{Digits}|\.)?
Number            {Digits}?{OPTIONAL_FRAC}
Letter            [a-zA-Z_]
ID                {Letter}({Letter}|{Digit})*
Type              int|float|list|str|bool
Symbol            "!"|"@"|"#"|"$"|"%"|"^"|"&"|"*"|"("|")"|"-"|"_"|"+"|"="|"{"|"["|"]"|"}"|";"|":"|"'"|"<"|","|">"|"."|"?"|"/"|" "
Str               \"({Letter}|{Digit}|{Symbol})*\"
Relational-op     \=\=|\!\=|\<|\>|\<\=|\>\=
Assign-op         \+\=|\-\=|\*\=|\/\=|\%\=|\<\<\=|\>\>\=|\&\=|\^\=|\|\=
Add-op            "+"|"-"
Mul-op            "*"|"/"|"%"

%x INDENTATION

%%

"append"    { printf("shift : append\n"); last_token_was_newline = 0; return APPEND; }
"return"    { printf("shift : return\n"); last_token_was_newline = 0; return RETURN; }
"print"     { printf("shift : print\n"); last_token_was_newline = 0; return PRINT; }
"range"     { printf("shift : range\n"); last_token_was_newline = 0; return RANGE; }
"pass"      { printf("shift : pass\n"); last_token_was_newline = 0; return PASS; }
"break"     { printf("shift : break\n"); last_token_was_newline = 0; return BREAK; }
"continue"  { printf("shift : continue\n"); last_token_was_newline = 0; return CONTINUE; }
"def"       { printf("shift : def\n"); last_token_was_newline = 0; return DEF; }
"if"        { printf("shift : if\n"); last_token_was_newline = 0; return IF; }
"elif"      { printf("shift : elif\n"); last_token_was_newline = 0; return ELIF; }
"else"      { printf("shift : else\n"); last_token_was_newline = 0; return ELSE; }
"class"     { printf("shift : class\n"); last_token_was_newline = 0; return CLASS; }
"for"       { printf("shift : for\n"); last_token_was_newline = 0; return FOR; }
"in"        { printf("shift : in\n"); last_token_was_newline = 0; return IN; }
"True"      { printf("shift : True\n"); last_token_was_newline = 0; return IDENTIFIER; }
"False"     { printf("shift : False\n"); last_token_was_newline = 0; return IDENTIFIER; }
"and"       { printf("shift : and\n"); last_token_was_newline = 0; return AND; }
"or"        { printf("shift : or\n"); last_token_was_newline = 0; return OR; }
"not"       { printf("shift : not\n"); last_token_was_newline = 0; return NOT; }
"->"        { printf("shift : ->\n"); last_token_was_newline = 0; return ARROW; }
{Type}      { printf("shift : %s\n", yytext); yylval.text = strdup(yytext); last_token_was_newline = 0; return TYPE; }
{ID}        { printf("shift : %s\n", yytext); yylval.text = strdup(yytext); last_token_was_newline = 0; return IDENTIFIER; }
{Str}       { printf("shift : %s\n", yytext); yylval.text = strdup(yytext); last_token_was_newline = 0; return STR; }
{Number}    { printf("shift : %s\n", yytext); yylval.text = strdup(yytext); last_token_was_newline = 0; return NUMBER; }
{Add-op}    { printf("shift : %s\n", yytext); last_token_was_newline = 0; return ADD_OP; }
{Mul-op}    { printf("shift : %s\n", yytext); last_token_was_newline = 0; return MUL_OP; }
{Relational-op}    { printf("shift : %s\n", yytext);last_token_was_newline = 0; return REL_OP; }
{Assign-op}    { printf("shift : %s\n", yytext); last_token_was_newline = 0; return ASSIGN_OP; }
\n          { printf("shift : NEWLINE\n"); last_token_was_newline = 1; BEGIN(INDENTATION); return NEWLINE; }
";"         { printf("shift : ;\n"); last_token_was_newline = 0; return ';'; }
","         { printf("shift : ,\n"); last_token_was_newline = 0; return ','; }
":"         { printf("shift : :\n"); last_token_was_newline = 0; return ':'; }
"("         { printf("shift : (\n"); last_token_was_newline = 0; return '('; }
")"         { printf("shift : )\n"); last_token_was_newline = 0; return ')'; }
"["         { printf("shift : [\n"); last_token_was_newline = 0; return '['; }
"]"         { printf("shift : ]\n"); last_token_was_newline = 0; return ']'; }
"."         { printf("shift : .\n"); last_token_was_newline = 0; return '.'; }
"="         { printf("shift : =\n"); last_token_was_newline = 0; return '='; }

<INDENTATION>^.*    {
                        char* line = strdup(yytext);
                        int len=0;
                        while(line[len] ==' ' || line[len] == '\t') len++;
                        free(line);
                        if(len > curr){
                            indent_stack[++top] = len;
                            curr = len;
                            printf("shift : INDENT\n");
                            yyless(len);  
                            BEGIN(INITIAL);
                            return INDENT;
                        }
                        else if(len < curr){
                            while(top > 0 && indent_stack[top] > len){
                                top--;
                                printf("shift : DEDENT\n");
                                yyless(0);  
                                BEGIN(INITIAL);
                                curr = indent_stack[top];
                                return DEDENT;
                            }
                            if(indent_stack[top] != len){
                                printf("<ERROR,indentation level does not match (fatal error and parse terminates)>\n");
                                exit(1);
                            }
                        }

                        yyless(len);
                        BEGIN(INITIAL);
                    }

^[ \t]+     {}

<<EOF>>     {
                if (!last_token_was_newline) {
                    last_token_was_newline = 1;
                    printf("shift : NEWLINE\n");
                    return NEWLINE;
                }
                while(top > 0) {
                    top--;
                    curr = indent_stack[top];
                    printf("shift : DEDENT\n");
                    return DEDENT;
                }
                printf("shift : ENDMARKER\n");
                return ENDMARKER;
            }

%%

int yywrap() {
    return 1; 
}
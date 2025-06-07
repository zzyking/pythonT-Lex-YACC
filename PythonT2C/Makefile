# Makefile for Python to C Transpiler

CC = gcc
LEX = flex
YACC = bison
CFLAGS = -Wall -g

all: py2c

py2c: lex.yy.c y.tab.c
	$(CC) $(CFLAGS) -o py2c lex.yy.c y.tab.c -L$(shell brew --prefix flex)/lib -lfl

lex.yy.c: lexer.l y.tab.h
	$(LEX) lexer.l

y.tab.c y.tab.h: parser.y
	$(YACC) -d -o y.tab.c parser.y

clean:
	rm -f py2c lex.yy.c y.tab.c y.tab.h *.o test.c test_output

test: py2c
	./py2c test.py
	$(CC) $(CFLAGS) -o test_output test.c
	./test_output

.PHONY: all clean test

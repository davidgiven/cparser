#include <config.h>

#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <string.h>

#include "lexer.h"
#include "token_t.h"
#include "type_hash.h"
#include "parser.h"

#if 0
static
void get_output_name(char *buf, size_t buflen, const char *inputname,
                     const char *newext)
{
	size_t last_dot = 0xffffffff;
	size_t i = 0;
	for(const char *c = inputname; *c != 0; ++c) {
		if(*c == '.')
			last_dot = i;
		++i;
	}
	if(last_dot == 0xffffffff)
		last_dot = i;

	if(last_dot >= buflen)
		panic("filename too long");
	memcpy(buf, inputname, last_dot);

	size_t extlen = strlen(newext) + 1;
	if(extlen + last_dot >= buflen)
		panic("filename too long");
	memcpy(buf+last_dot, newext, extlen);
}
#endif

static
translation_unit_t *do_parsing(const char *fname)
{
	FILE *in = fopen(fname, "r");
	if(in == NULL) {
		fprintf(stderr, "Couldn't open '%s': %s\n", fname, strerror(errno));
		exit(1);
	}

	lexer_open_stream(in, fname);

	translation_unit_t *unit = parse();

	fclose(in);

	return unit;
}

static
void lextest(const char *fname)
{
	FILE *in = fopen(fname, "r");
	if(in == NULL) {
		fprintf(stderr, "Couldn't open '%s': %s\n", fname, strerror(errno));
		exit(1);
	}

	lexer_open_stream(in, fname);

	do {
		lexer_next_preprocessing_token();
		print_token(stdout, &lexer_token);
		puts("");
	} while(lexer_token.type != T_EOF);

	fclose(in);
}

void write_fluffy_decls(translation_unit_t *unit);

int main(int argc, char **argv)
{
	init_symbol_table();
	init_tokens();
	init_lexer();
	init_types();
	init_typehash();
	init_ast();
	init_parser();

	if(argc > 2 && strcmp(argv[1], "--lextest") == 0) {
		lextest(argv[2]);
		return 0;
	}

	if(argc > 2 && strcmp(argv[1], "--print-ast") == 0) {
		translation_unit_t *unit = do_parsing(argv[2]);
		ast_set_output(stdout);
		print_ast(unit);
		return 0;
	}

	if(argc > 2 && strcmp(argv[1], "--print-fluffy") == 0) {
		translation_unit_t *unit = do_parsing(argv[2]);
		ast_set_output(stdout);
		write_fluffy_decls(unit);
		return 0;
	}

	for(int i = 1; i < argc; ++i) {
		do_parsing(argv[i]);
	}

	exit_parser();
	exit_ast();
	exit_typehash();
	exit_types();
	exit_lexer();
	exit_tokens();
	exit_symbol_table();
	return 0;
}

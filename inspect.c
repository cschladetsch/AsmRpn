
#include <stdio.h>
#include <stdint.h>
#include <string.h>

extern long tokenize(char *buffer);
extern long parse_tokens(uint64_t *tokens, long count);
extern long translate(uint64_t *ops, long count);
extern void execute(uint64_t *bytecode, long count);
uint64_t token_ptrs[256];
uint64_t op_list[512];
uint64_t bytecode[512];
uint64_t string_offset;
unsigned char string_pool[100000];
uint64_t literal_offset;
uint64_t literal_pool[2048];
uint64_t variables[256];
unsigned char var_types[256];
uint64_t stack[10000];
int64_t stack_top=-1;
unsigned char stack_types[10000];
unsigned char output_buffer[32];
void maybe_write_color(void) {}

int main(){
    char buf[] = ""foo"
";
    long t = tokenize(buf);
    long ops = parse_tokens(token_ptrs, t);
    long bc = translate(op_list, ops);
    for(long i=0;i<bc;i++)
        printf("op%ld=%llu val=%llu
", i, (unsigned long long)bytecode[i*2], (unsigned long long)bytecode[i*2+1]);
    execute(bytecode, bc);
    printf("stack_top=%lld
", (long long)stack_top);
    for(int i=0;i<=stack_top;i++) printf("stack[%d]=%lld type=%u
",i,(long long)stack[i],stack_types[i]);
}

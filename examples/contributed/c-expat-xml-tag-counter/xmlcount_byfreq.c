#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <expat.h>

#define BUF_SIZE 4096
#define HASH_BUCKETS 257	/* prime, keeps distribution reasonable for small N */

typedef struct TagNode {
	char *name;
	long count;
	struct TagNode *next;
} TagNode;

static TagNode *buckets[HASH_BUCKETS];
static int n_distinct = 0;

/* simple djb2-style string hash */
static unsigned long
hash_str(const char *s) {
	unsigned long h = 5381;
	int c;
	while ((c = (unsigned char)*s++)) {
		h = ((h << 5) + h) + c;	/* h * 33 + c */
	}
	return h;
}

static void
tag_increment(const char *name) {
	unsigned long idx = hash_str(name) % HASH_BUCKETS;
	TagNode *node = buckets[idx];

	while (node) {
		if (strcmp(node->name, name) == 0) {
			node->count++;
			return;
		}
		node = node->next;
	}

	node = malloc(sizeof(TagNode));
	node->name = strdup(name);
	node->count = 1;
	node->next = buckets[idx];
	buckets[idx] = node;
	n_distinct++;
}

static void XMLCALL
start_element(void *userData, const XML_Char *name, const XML_Char **atts) {
	(void)userData;
	(void)atts;
	tag_increment(name);
}

typedef struct {
	const char *name;
	long count;
} FlatEntry;

/* descending by count; ties broken alphabetically for stable output */
static int
compare_entries(const void *a, const void *b) {
	const FlatEntry *fa = (const FlatEntry *)a;
	const FlatEntry *fb = (const FlatEntry *)b;
	if (fb->count != fa->count) {
		return (fb->count > fa->count) - (fb->count < fa->count);
	}
	return strcmp(fa->name, fb->name);
}

static void
free_table(void) {
	for (int i = 0; i < HASH_BUCKETS; i++) {
		TagNode *node = buckets[i];
		while (node) {
			TagNode *next = node->next;
			free(node->name);
			free(node);
			node = next;
		}
	}
}

int main(int argc, char *argv[]) {
	if (argc != 2) {
		fprintf(stderr, "Usage: %s <file.xml>\n", argv[0]);
		return 1;
	}

	const char *path = argv[1];
	FILE *f = fopen(path, "rb");
	if (!f) {
		perror("fopen");
		return 1;
	}

	XML_Parser parser = XML_ParserCreate(NULL);
	XML_SetElementHandler(parser, start_element, NULL);

	char buf[BUF_SIZE];
	int done = 0;

	printf("Parsing: %s\n", path);

	struct timespec t_start, t_end;
	clock_gettime(CLOCK_MONOTONIC, &t_start);

	while (!done) {
		size_t len = fread(buf, 1, BUF_SIZE, f);
		done = len < BUF_SIZE;
		if (XML_Parse(parser, buf, (int)len, done) == XML_STATUS_ERROR) {
			fprintf(stderr, "Parse error at line %lu: %s\n",
					XML_GetCurrentLineNumber(parser),
					XML_ErrorString(XML_GetErrorCode(parser)));
			fclose(f);
			XML_ParserFree(parser);
			free_table();
			return 1;
		}
	}

	clock_gettime(CLOCK_MONOTONIC, &t_end);
	double elapsed_ms = (t_end.tv_sec - t_start.tv_sec) * 1000.0 +
						(t_end.tv_nsec - t_start.tv_nsec) / 1.0e6;

	fclose(f);
	XML_ParserFree(parser);

	printf("Parsing time: %.0f ms\n", elapsed_ms);
	printf("Tags sorted in order of occurrence count (Highest first)\n\n");

	FlatEntry *flat = malloc(sizeof(FlatEntry) * n_distinct);
	int idx = 0;
	for (int i = 0; i < HASH_BUCKETS; i++) {
		for (TagNode *node = buckets[i]; node; node = node->next) {
			flat[idx].name = node->name;
			flat[idx].count = node->count;
			idx++;
		}
	}

	qsort(flat, n_distinct, sizeof(FlatEntry), compare_entries);

	for (int i = 0; i < n_distinct; i++) {
		printf("TAG: <%s> occurrences %ld\n", flat[i].name, flat[i].count);
	}

	free(flat);
	free_table();

	return 0;
}

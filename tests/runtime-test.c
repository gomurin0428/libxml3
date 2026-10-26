#define _XOPEN_SOURCE 700

#include <libxml3.h>
#include <libxml/parser.h>
#include <libxml/tree.h>
#include <assert.h>
#include <pthread.h>
#include <sched.h>
#include <stdio.h>
#include <string.h>

#ifndef XML3_RUNTIME_NO_OOM
void xml3_oom_enable(long index);
void xml3_oom_disable(void);
int xml3_oom_was_injected(void);
#endif

enum { THREAD_COUNT = 4, ITERATIONS = 32 };

struct thread_context {
    pthread_barrier_t *start;
    int id;
};

static void *exercise_private_document(void *opaque) {
    struct thread_context *context = opaque;
    int iteration;

    pthread_barrier_wait(context->start);
    for (iteration = 0; iteration < ITERATIONS; ++iteration) {
        static const char input[] = "<root><initial>text</initial></root>";
        char value[64];
        xmlDocPtr doc;
        xmlNodePtr root;
        xmlNodePtr child;
        xmlChar *content;

        snprintf(value, sizeof(value), "%d-%d", context->id, iteration);
        doc = xmlReadMemory(input, (int)strlen(input), NULL, NULL, 0);
        assert(doc != NULL);
        root = xmlDocGetRootElement(doc);
        assert(root != NULL && xmlChildElementCount(root) == 1);
        assert(root->doc == doc && root->children != NULL);
        assert(root->children->parent == root && root->children->doc == doc);
        assert(xmlSetProp(root, BAD_CAST "worker-id", BAD_CAST value) != NULL);
        content = xmlGetProp(root, BAD_CAST "worker-id");
        assert(content != NULL && strcmp((const char *)content, value) == 0);
        xmlFree(content);
        child = xmlNewNode(NULL, BAD_CAST "worker");
        assert(child != NULL);
        assert(xmlSetProp(child, BAD_CAST "iteration", BAD_CAST value) != NULL);
        assert(child->type == XML_ELEMENT_NODE && child->parent == NULL);
        content = xmlGetProp(child, BAD_CAST "iteration");
        assert(content != NULL && strcmp((const char *)content, value) == 0);
        xmlFree(content);
        content = xmlNodeGetContent(root);
        assert(content != NULL && strcmp((const char *)content, "text") == 0);
        xmlFree(content);
        assert(xmlFirstElementChild(root) != NULL);
        xmlFreeNode(child);
        xmlFreeDoc(doc);
    }
    return NULL;
}

static void test_oom_recovery_and_parallel_calls(void) {
#ifndef XML3_RUNTIME_NO_OOM
    int status = -1;
    int injected;
    xmlDocPtr doc;

    xml3_oom_enable(4);
    doc = xml3ReadMemory("<r><x/></r>", 11, &status);
    injected = xml3_oom_was_injected();
    xml3_oom_disable();
    assert(injected && doc == NULL && status == XML3_STATUS_NO_MEMORY);
    xmlResetLastError();
#endif

    {
        xmlDocPtr doc = xmlNewDoc(NULL);
        assert(doc != NULL);
        xmlFreeDoc(doc);
    }

    {
        pthread_t threads[THREAD_COUNT];
        struct thread_context contexts[THREAD_COUNT];
        pthread_barrier_t start;
        int index;

        assert(pthread_barrier_init(&start, NULL, THREAD_COUNT) == 0);
        for (index = 0; index < THREAD_COUNT; ++index) {
            contexts[index].start = &start;
            contexts[index].id = index;
            assert(pthread_create(&threads[index], NULL,
                                  exercise_private_document,
                                  &contexts[index]) == 0);
        }
        for (index = 0; index < THREAD_COUNT; ++index)
            assert(pthread_join(threads[index], NULL) == 0);
        assert(pthread_barrier_destroy(&start) == 0);
    }
}

int main(void) {
    test_oom_recovery_and_parallel_calls();
    puts("Serialized runtime tests passed");
    return 0;
}

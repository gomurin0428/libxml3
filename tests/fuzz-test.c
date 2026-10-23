#include <libxml3.h>

#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#define FUZZ_SEED UINT32_C(0x6d2b79f5)
#define FUZZ_ITERATIONS 1000

static uint32_t next_random(uint32_t *state) {
    uint32_t value = *state;
    value ^= value << 13;
    value ^= value >> 17;
    value ^= value << 5;
    *state = value;
    return value;
}

int main(void) {
    static const char *const seeds[] = {
        "<root><child/></root>",
        "<r a='value' b=\"two\"/>",
        "<r>&#65;&amp;text</r>",
        "<r><!-- comment --></r>",
        "<r><![CDATA[content]]></r>",
        "<r><?target data?></r>",
        "<r xmlns:p='urn:test'><p:item/></r>",
        "<?xml version='1.0'?><r>text</r>"
    };
    static const unsigned char ascii[] =
        "<>/!?&;#x0123456789 abcdefghijklmnopqrstuvwxyz"
        "ABCDEFGHIJKLMNOPQRSTUVWXYZ='\"-_:.";
    static const char *const utf16_seed =
        "<?xml version='1.0' encoding='UTF-8'?>"
        "<r a='v'>&#65;<!--c--><![CDATA[d]]><?p e?>"
        "<p:x xmlns:p='urn:n'/></r>";
    static const unsigned char invalid[] = {0xff, 0xc0, 0xed, 0xa0};
    uint32_t state = FUZZ_SEED;
    unsigned char input[256];

    for (unsigned iteration = 0; iteration < FUZZ_ITERATIONS; ++iteration) {
        size_t length;
        unsigned mode = iteration % 6;
        if (mode == 2) {
            length = next_random(&state) % 96;
            for (size_t i = 0; i < length; ++i)
                input[i] = (char)ascii[next_random(&state) % (sizeof(ascii) - 1)];
        } else if (mode == 4 || mode == 5) {
            size_t seed_length = strlen(utf16_seed);
            size_t complete_length = 2 + seed_length * 2;
            assert(complete_length <= sizeof(input));
            input[0] = 0xff;
            input[1] = 0xfe;
            for (size_t i = 0; i < seed_length; ++i) {
                input[2 + i * 2] = (unsigned char)utf16_seed[i];
                input[3 + i * 2] = 0;
            }
            if (mode == 4) {
                static const unsigned char mutations[] =
                    {0x00, 0x01, 0x80, 0xd8, 0xff};
                length = complete_length;
                size_t position = next_random(&state) % length;
                input[position] =
                    mutations[next_random(&state) % sizeof(mutations)];
            } else {
                length = next_random(&state) % (complete_length + 1);
            }
        } else {
            const char *seed =
                seeds[next_random(&state) % (sizeof(seeds) / sizeof(seeds[0]))];
            length = strlen(seed);
            memcpy(input, seed, length);
            size_t position = next_random(&state) % length;
            if (mode == 3) {
                input[position] =
                    (char)invalid[next_random(&state) % sizeof(invalid)];
            } else {
                input[position] =
                    (char)ascii[next_random(&state) % (sizeof(ascii) - 1)];
            }
        }

        xmlResetLastError();
        xmlDocPtr doc =
            xmlReadMemory((const char *)input, (int)length, NULL, NULL, 0);
        const xmlError *error = xmlGetLastError();
        xmlError copy = {0};
        if (doc == NULL) {
            assert(error != NULL);
            assert(error->code != XML_ERR_OK);
        } else {
            if (error != NULL) {
                assert(error->code == 113);
                assert(error->level == XML_ERR_WARNING);
            }
        }
        if (error != NULL) {
            assert(xmlCopyError(error, &copy) == 0);
            assert(copy.message != NULL);
            assert(copy.message != error->message);
        }
        xmlResetError(&copy);
        if (doc != NULL)
            xmlFreeDoc(doc);
        xmlResetLastError();
        doc = xmlReadMemory("<fuzz/>", 7, NULL, NULL, 0);
        assert(doc != NULL);
        xmlFreeDoc(doc);
        assert(xmlGetLastError() == NULL);
    }
    printf("bounded malformed-input smoke passed: seed=0x%08x iterations=%d\n",
           FUZZ_SEED, FUZZ_ITERATIONS);
    return 0;
}

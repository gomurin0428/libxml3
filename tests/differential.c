#include <libxml/parser.h>
#include <libxml/tree.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void string_value(const xmlChar *value) {
    if (!value) {
        fputs("null", stdout);
        return;
    }
    for (; *value; ++value) printf("%02x", (unsigned)*value);
}

static void dump(xmlNodePtr node) {
    for (; node; node = node->next) {
        printf("(%d ", (int)node->type);
        string_value(node->name);
        fputc(' ', stdout);
        xmlChar *content = xmlNodeGetContent(node);
        string_value(content);
        xmlFree(content);
        if (node->type == XML_ELEMENT_NODE) {
            for (xmlAttrPtr attr = node->properties; attr; attr = attr->next) {
                fputs(" @", stdout);
                string_value(attr->name);
                fputc('=', stdout);
                xmlChar *value = xmlGetProp(node, attr->name);
                string_value(value);
                xmlFree(value);
            }
        }
        dump(node->children);
        fputc(')', stdout);
    }
}

int main(void) {
    static const char *const inputs[] = {
        "<root/>",
        "<root></root>",
        "<root a='one' b=\"two\"><child/>before<child>inside</child>after</root>",
        "<?xml version='1.0'?><root>hello</root>",
        "<?xml version=\"1.0\" encoding='UTF-8' standalone='yes'?><root/>",
        "\xef\xbb\xbf<root>\xe6\x97\xa5\xe6\x9c\xac\xf0\x9f\x98\x80</root>",
        "<root a='&lt;&gt;&amp;&apos;&quot;'>&lt;&gt;&amp;&apos;&quot;</root>",
        "<root a='&#9;&#10;&#13;'>a&#65;&#x20AC;&#x1F600;</root>",
        "<root a='a\tb\r\nc\rd\ne'>x\r\ny\rz\n</root>",
        "<!--before--><?job start?><root><!--inside--><![CDATA[<x>&raw]]><?job end?></root><!--after-->",
        "<root><a><b><c>text</c></b></a><empty/></root>",
        "<root a='' b=''><![CDATA[]]></root>",
        " \n<root> \n\t <child/> </root>\n",
        "<root><?xml-stylesheet href='local'?>tail</root>",
        "<root>&#x10FFFF;&#xD7FF;&#xE000;</root>"
    };
    xmlInitParser();
    for (size_t i = 0; i < sizeof(inputs) / sizeof(inputs[0]); ++i) {
        xmlDocPtr doc = xmlReadMemory(inputs[i], (int)strlen(inputs[i]),
                                     NULL, NULL, XML_PARSE_NONET);
        if (!doc || !xmlDocGetRootElement(doc)) {
            fprintf(stderr, "accepted fixture %zu failed\n", i);
            return EXIT_FAILURE;
        }
        printf("%zu:", i);
        dump(doc->children);
        fputc('\n', stdout);
        xmlFreeDoc(doc);
    }
    xmlCleanupParser();
    return EXIT_SUCCESS;
}

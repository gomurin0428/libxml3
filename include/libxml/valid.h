#ifndef LIBXML3_VALID_H
#define LIBXML3_VALID_H

#include <libxml/xmlstring.h>

#ifdef __cplusplus
extern "C" {
#endif

int xmlValidateNameValue(const xmlChar *value);
int xmlValidateNamesValue(const xmlChar *value);
int xmlValidateNmtokenValue(const xmlChar *value);
int xmlValidateNmtokensValue(const xmlChar *value);

#ifdef __cplusplus
}
#endif

#endif

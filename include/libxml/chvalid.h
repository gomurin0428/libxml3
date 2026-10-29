#ifndef LIBXML3_CHVALID_H
#define LIBXML3_CHVALID_H

#ifdef __cplusplus
extern "C" {
#endif

int xmlIsChar(unsigned int ch);
int xmlIsBlank(unsigned int ch);
int xmlIsDigit(unsigned int ch);
int xmlIsExtender(unsigned int ch);
int xmlIsIdeographic(unsigned int ch);
int xmlIsPubidChar(unsigned int ch);

#ifdef __cplusplus
}
#endif

#endif

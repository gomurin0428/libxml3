#ifndef LIBXML3_CHVALID_H
#define LIBXML3_CHVALID_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct _xmlChSRange xmlChSRange;
typedef xmlChSRange *xmlChSRangePtr;
struct _xmlChSRange {
    unsigned short low;
    unsigned short high;
};

typedef struct _xmlChLRange xmlChLRange;
typedef xmlChLRange *xmlChLRangePtr;
struct _xmlChLRange {
    unsigned int low;
    unsigned int high;
};

typedef struct _xmlChRangeGroup xmlChRangeGroup;
typedef xmlChRangeGroup *xmlChRangeGroupPtr;
struct _xmlChRangeGroup {
    int nbShortRange;
    int nbLongRange;
    const xmlChSRange *shortRange;
    const xmlChLRange *longRange;
};

int xmlCharInRange(unsigned int val, const xmlChRangeGroup *group);
int xmlIsChar(unsigned int ch);
int xmlIsBlank(unsigned int ch);
int xmlIsDigit(unsigned int ch);
int xmlIsExtender(unsigned int ch);
int xmlIsIdeographic(unsigned int ch);
int xmlIsPubidChar(unsigned int ch);
int xmlIsBaseChar(unsigned int ch);
int xmlIsCombining(unsigned int ch);

#ifdef __cplusplus
}
#endif

#endif

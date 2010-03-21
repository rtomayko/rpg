/* Fast package list solver.
 *
 * THIS IS A MESS. SORRY. I STILL NEED TO CLEAN IT UP.
 *
 * TODO:
 * [ ] usage message
 * [ ] default to release index file
 */
#include <stdlib.h>
#include <stdio.h>
#include <ctype.h>
#include <string.h>
#include "strnatcmp.h"

enum OPER { lt, le, eq, ge, gt, st, err };

/* A package list entry. */
struct plent {
    int found;
    enum OPER oper;
    char pack[100];
    char vers[50];
    struct plent *next;
};

/* Parse a comparison operator string and return the corresponding OPER
 * value. The err value is returned if the string is not a valid operator.
 */
static inline enum OPER
operparse (char * oper) 
{
    enum OPER res = err;
    if ( oper[0] == '<' ) {
        if ( oper[1] == 0 ) {
            res = lt;
        } else if ( oper[1] == '=' ) {
            res = le;
        }
    } else if ( oper[0] == '>' ) {
        if ( oper[1] == 0 ) {
            res = gt;
        } else if ( oper[1] == '=' ) {
            res = ge;
        }
    } else if ( oper[0] == '=' && oper[1] == 0 ) {
        res = eq;
    } else if ( oper[0] == '~' && oper[1] == '>' ) {
        res = st;
    }

    return res;
}

/* Replace vers with its next successive version. */
inline void
versucc (char * vers) {
    char *pdot = strrchr(vers, '.');
    char *pend = NULL;

    if ( pdot == NULL ) {
        pdot = strrchr(vers, '\0');
        *pdot = '.';
    }

    pdot++;
    for (pend = pdot + 10; pdot < pend; pdot++)
        *pdot = '9';
    *pdot = '\0';
}

/* Expand squiggly comparisons into separate ge and lt comparisons. e.g.,
 * foo ~> 0.2.3 would become foo >= 0.2.3 and foo < 0.3.*/
static void
plsquig (struct plent * pe)
{
    struct plent * pnew;
    while (pe) {
        if (pe->oper != st) {
            pe = pe->next;
            continue;
        }

        pe->oper = ge;
        pnew = malloc(sizeof(struct plent));
        memcpy(pnew, pe, sizeof(struct plent));
        pnew->oper = lt;
        versucc(pnew->vers);
        pe->next = pnew;
        pe = pnew->next;
    }
}

/* Parse a package list from the stream. */
static struct plent *
plparse (FILE * stream)
{
    int res = 0, lineno = 0;
    struct plent *pe, *ppe = NULL, *pfe = NULL;
    char stroper[3];
    const char * format = "%100s%*[ ]%2[~><=]%*[ ]%50s\n";

    while (1) {
        lineno++;
        pe = malloc(sizeof(struct plent));
        pe->found = 0;
        pe->next = NULL;

        res = fscanf(stream, format, pe->pack, stroper, pe->vers);
        if ( res == 3 ) {
            pe->oper = operparse(stroper);
        } else {
            free(pe);
            break;
        }

        if ( ppe ) ppe->next = pe;
        else pfe = pe;
        ppe = pe;
    }

    plsquig(pfe);
    return pfe;
}


/* Mark all package list entries whose package name matches pack as found. */
static inline void
plmark (struct plent * pe, char * pack)
{
    int cmp;
    for (; pe != NULL; pe = pe->next) {
        cmp = strcmp(pe->pack, pack);
        if (cmp == 0) {
            pe->found = 1;
        } else if (cmp < 0) {
            continue;
        } else {
            break;
        }
    }
}

/* Remove entries marked as found from the list. */
static struct plent *
plpurge (struct plent * pe) {
    struct plent * ptail = NULL,
                 * phead = NULL;

    for (;pe != NULL; pe = pe->next) {
        if ( pe->found ) continue;

        if ( ptail )
            ptail->next = pe;
        else
            phead = pe;

        ptail = pe;
        ptail->next = NULL;
    }

    return phead;
}

/* Compare two versions. */
static inline int
verscmp(char const * v1, char const * v2)
{
    return strnatcmp(v1, v2);
}

/* Test if versions compare according to oper. */
static inline int
verstest(enum OPER oper, char const * v1, char const * v2)
{
    int res = 0;
    int cmp;
    if (oper == eq) {
        cmp = strcmp(v1, v2);
        if (cmp == 0) res = 1;
    } else {
        cmp = verscmp(v1, v2);
        if ((cmp == 0 && (oper == le || oper == ge)) ||
            (cmp  < 0 && (oper == lt || oper == le)) ||
            (cmp  > 0 && (oper == gt || oper == ge)))
            res = 1;
    }
    return res;
}

/* Run over all package list entries with the same name as ppack and compare
 * versions.
 */
static int
pdxrun(char * ppack, char * pvers, struct plent * pe)
{
    while ( pe && strcmp(ppack, pe->pack) == 0 ) {
        if (verstest(pe->oper, pvers, pe->vers)) {
            pe = pe->next;
        } else {
            return 0;
        }
    }
    return 1;
}

#define MAXLINE 256

static void
pdxscan(FILE * stream, struct plent * pe)
{
    char line[MAXLINE];
    char *ppack, *pvers;
    int cmp;

    while ( fgets(line, MAXLINE - 1, stream) ) {
        if (pe->pack[0] > line[0]) continue;

        pvers = line;
        ppack = strsep(&pvers, " ");
        while ((cmp = strcmp(pe->pack, ppack)) < 0) {
            pe = pe->next;
            if (pe == NULL) return;
        }

        if (cmp > 0) continue;

        pvers = strsep(&pvers, " \n");
        if (pdxrun(ppack, pvers, pe)) {
            if ( pe->found == 0 )
                plmark(pe, ppack);
            printf("%s %s\n", ppack, pvers);
        }
    }
}

int main (int argc, char *argv[])
{
    struct plent * pe = plparse(stdin);
    FILE * fidx;
    int i;

    for (i=1; i < argc; i++) {
        if (pe == NULL)
            break;

        if ((fidx = fopen(argv[i], "r"))) {
            pdxscan(fidx, pe);
            fclose(fidx);
        }

        pe = plpurge(pe);
    }

    /* some packages were not found */
    if ( pe ) {
        while ( pe ) {
            printf("%s -\n", pe->pack);
            pe = pe->next;
        }
        return 1;
    }

    return 0;
}

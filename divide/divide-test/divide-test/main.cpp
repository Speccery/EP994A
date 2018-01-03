//
//  main.cpp
//  divide-test
//
//  Created by Erik Piehl on 14/09/2017.
//  Copyright © 2017 Erik Piehl. All rights reserved.
//

#include <stdio.h>

unsigned short tms9900_div(unsigned int divident, int divisor) {
    unsigned short sa;      // source argument
    unsigned short da0;     // destination argument (high 16 bits)
    unsigned short da1;     // destination argument (low 16 bits);
    printf("divident: %d divisor: %d\n", divident, divisor);
    // algorithm
    da0 = (divident >> 16);
    da1 = divident & 0xFFFF;
    sa = divisor;
    
    int st4;
    if (
        (((sa & 0x8000) == 0 && (da0 & 0x8000) == 0x8000))
        || ((sa & 0x8000) == (da0 & 0x8000) && (((da0 - sa) & 0x8000) == 0))
        ) {
        st4 = 1;
    } else {
        st4 = 0;
        // actual division loop, here sa is known to be larger than da0.
        for(int i=0; i<16; i++) {
            da0 = (da0 << 1) | ((da1 >> 15) & 1);
            da1 <<= 1;
            if(da0 >= sa) {
                da0 -= sa;
                da1 |= 1;   // successful substraction
            }
        }
    }
    printf("quotiotent: %d remainder %d st4=%d\n", da1, da0, st4);
    printf("checking: quotiotent %d remainder %d\n\n", divident/divisor, divident % divisor);
    return da1;
}

int main(int argc, const char * argv[]) {
    
    tms9900_div(62000, 15);
    tms9900_div(100, 10);
    tms9900_div(62000, 2);
    tms9900_div(100, 200);
    tms9900_div(200000, 2);
    
    return 0;
}

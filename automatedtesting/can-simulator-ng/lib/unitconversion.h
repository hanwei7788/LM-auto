/*!
* \file
* \brief unitconversion.h foo
*
* Copyright of Link Motion Ltd. All rights reserved.
*
* Contact: info@link-motion.com
*
* \author Matti Lehtimäki <matti.lehtimaki@nomovok.com>
* \author Lari Koskinen <lari.koskinen@link-motion.com>
*
* any other legal text to be defined later
*/

#ifndef UNITCONVERSION_H
#define UNITCONVERSION_H

#include <string>

// Conversion types to avoid repetitive string comparison in conversion
enum class ConvertTo {
    NONE = 0,
    MI,
    KM,
    KMH,
    MPH,
    MS,
    F,
    K
};

ConvertTo unitToConversionType(std::string conversion);
bool unitConversion(long double &value, ConvertTo conversion);

#endif // UNITCONVERSION_H

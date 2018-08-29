/*!
* \file
* \brief value.h foo
*
* Copyright of Link Motion Ltd. All rights reserved.
*
* Contact: info@link-motion.com
*
* \author Matti Lehtimäki <matti.lehtimaki@nomovok.com>
*
* any other legal text to be defined later
*/

#ifndef VALUE_H
#define VALUE_H

#include <string>

class Value
{
public:
    enum Type { Integer, Double, Unsigned };
    Value();
    explicit Value(int i);
    explicit Value(double d);
    explicit Value(unsigned long i);
    Value(const Value& other);
    int toInt() const;
    double toDouble() const;
    std::string toString() const;
    unsigned long toUnsigned() const;
    Type type() const;
    bool operator==(const Value &other) const;
    bool operator!=(const Value &other) const;
    Value & operator=(const Value &other);
private:
    union {
        int i;
        double d;
        unsigned long u;
    } m_data;

    Type m_dataType;
};

#endif // VALUE_H

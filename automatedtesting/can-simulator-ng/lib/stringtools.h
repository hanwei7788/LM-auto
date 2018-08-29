/*!
* \file
* \brief stringtools.h foo
*
* Copyright of Link Motion Ltd. All rights reserved.
*
* Contact: info@link-motion.com
*
* \author Matti Lehtimäki <matti.lehtimaki@nomovok.com>
*
* any other legal text to be defined later
*/

#ifndef STRINGTOOLS_H
#define STRINGTOOLS_H

#include <string>
#include <vector>

std::string& trim(std::string& str, const std::string& delim);

std::vector<std::string>& split(const std::string &str, char delim, std::vector<std::string> &items);

std::vector<std::string> split(const std::string &str, char delim);

#endif // STRINGTOOLS_H

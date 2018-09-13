/*!
* \file
* \brief commandlineparser.h foo
*
* Copyright of Link Motion Ltd. All rights reserved.
*
* Contact: info@link-motion.com
*
* \author Matti Lehtimäki <matti.lehtimaki@nomovok.com>
*
* any other legal text to be defined later
*/

#ifndef COMMANDLINEPARSER_H
#define COMMANDLINEPARSER_H

#include <string>
#include <vector>

struct parameters {
    std::string asc;
    std::string cfg;
    std::string dbc;
    std::string interface;
    std::string metrics;
    char metricsSeparator;
    bool native;
    int runTime;
    bool suppressDefaults;
    bool ignoreDirections;
    bool sendTime;
    bool utcTime;
    bool filterExclude;
    int verbosity;
    std::string command;
    std::string filters;
    std::vector<std::string> commandParameters;
};

// Parsed command line parameter values
extern parameters params;

bool parseCommandLineArguments(int argc, char *argv[]);

#endif // COMMANDLINEPARSER_H

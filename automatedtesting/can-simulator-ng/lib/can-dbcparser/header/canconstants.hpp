/*!
* \file
* \brief canconstants.hpp foo
*
* Copyright of Link Motion Ltd. All rights reserved.
*
* Contact: info@link-motion.com
*
* \author Matti Lehtimäki <matti.lehtimaki@nomovok.com>
*
* any other legal text to be defined later
*/

#ifndef CANCONSTANTS_HPP_
#define CANCONSTANTS_HPP_

// Constants for dbc parser

#define DBC_ATTRIBUTE_DEFINITION "BA_DEF_"
#define DBC_ATTRIBUTE_VALUE "BA_"
#define DBC_ATTRIBUTE_VALUE_DEFAULT "BA_DEF_DEF_"
#define DBC_BIT_TIMING "BS_" // Obsolete but required
#define DBC_DESCRIPTION "CM_"
#define DBC_ENVIRONMENT_VARIABLE "EV_"
#define DBC_ENVIRONMENT_VARIABLE_DATA "ENVVAR_DATA_"
#define DBC_MESSAGE "BO_"
#define DBC_MESSAGE_TX_NODE "BO_TX_BU_"
#define DBC_NODE "BU_"
#define DBC_SIGNAL "SG_"
#define DBC_SIGNAL_GROUP "SIG_GROUP_"
#define DBC_SIGNAL_VALUE_TYPE "SIG_VALTYPE_"
#define DBC_VALUE_DESCRIPTION "VAL_"
#define DBC_VALUE_TABLE "VAL_TABLE_"
#define DBC_VERSION "VERSION"

#define DBC_MULTIPLEXED "m"
#define DBC_MULTIPLEXOR "M"

#define DBC_SIGN_UNSIGNED "+"
#define DBC_SIGN_SIGNED   "-"

// Byte orders
#define DBC_BYTEORDER_MOTOROLA 0
#define DBC_BYTEORDER_INTEL    1

// Value types
// used in DBC_SIGNAL_VALUE_TYPE
#define DBC_VALUE_TYPE_INTEGER 0
#define DBC_VALUE_TYPE_FLOAT   1 // 32-bit float
#define DBC_VALUE_TYPE_DOUBLE  2 // 64-bit double

// Attribute types
#define DBC_ATTRIBUTE_TYPE_INTEGER "INT"
#define DBC_ATTRIBUTE_TYPE_HEX     "HEX"
#define DBC_ATTRIBUTE_TYPE_FLOAT   "FLOAT"
#define DBC_ATTRIBUTE_TYPE_STRING  "STRING"
#define DBC_ATTRIBUTE_TYPE_ENUM    "ENUM"

#endif /* CANCONSTANTS_HPP_ */

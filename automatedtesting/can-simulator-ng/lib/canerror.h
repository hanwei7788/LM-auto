/*!
* \file
* \brief canerror.h foo
*
* Copyright of Link Motion Ltd. All rights reserved.
*
* Contact: info@link-motion.com
*
* \author Matti Lehtimäki <matti.lehtimaki@nomovok.com>
*
* any other legal text to be defined later
*/

#ifndef CANERROR_H
#define CANERROR_H

#include <string>

extern "C" {
#include <linux/can.h>
#include <linux/can/error.h>
}

std::string analyzeErrorFrame(canfd_frame *frame);

#endif // CANERROR_H

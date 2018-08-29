/*!
* \file
* \brief test_LIB_canframe.cpp foo
*
* Copyright of Link Motion Ltd. All rights reserved.
*
* Contact: info@link-motion.com
*
* \author Matti Lehtimäki <matti.lehtimaki@nomovok.com>
*
* any other legal text to be defined later
*/

#include "dummy_logger.h"

#include "../lib/ascreader.cpp"
#include "../lib/canmessage.cpp"
#include "../lib/cansignal.cpp"
#include "../lib/cansimulatorcore.cpp"
#include "../lib/cantransceiver.cpp"
#include "../lib/configuration.cpp"
#include "../lib/can-dbcparser/attribute.cpp"
#include "../lib/can-dbcparser/dbciterator.cpp"
#include "../lib/can-dbcparser/message.cpp"
#include "../lib/can-dbcparser/signal.cpp"
#include "../lib/stringtools.cpp"
#include "../lib/unitconversion.cpp"
#include "../lib/value.cpp"
#include <linux/can.h>
#include <gtest/gtest.h>

void empty_canframe(canfd_frame &frame) {
    memset(&frame, 0, sizeof(struct canfd_frame));
}

TEST(LIB_canframe, test_assemble) {
    Configuration *config = NULL;
    ASSERT_NO_THROW(config = new Configuration("tests.cfg", "tests.dbc"));

    canfd_frame frame;
    empty_canframe(frame);
    config->getMessage("test1sig1")->assembleCANFrame(&frame);
    ASSERT_EQ(0, frame.data[0]);
    ASSERT_EQ(0, frame.data[1]);
    ASSERT_EQ(25, frame.data[2]);
    ASSERT_EQ(0, frame.data[3]);
    ASSERT_EQ(0, frame.data[4]);
    ASSERT_EQ(0, frame.data[5]);
    ASSERT_EQ(0, frame.data[6]);
    ASSERT_EQ(0, frame.data[7]);

    empty_canframe(frame);
    config->setValue("test1sig1", "1");
    config->getMessage("test1sig1")->assembleCANFrame(&frame);
    ASSERT_EQ(1, frame.data[0]);
    ASSERT_EQ(0, frame.data[1]);
    ASSERT_EQ(25, frame.data[2]);
    ASSERT_EQ(0, frame.data[3]);
    ASSERT_EQ(0, frame.data[4]);
    ASSERT_EQ(0, frame.data[5]);
    ASSERT_EQ(0, frame.data[6]);
    ASSERT_EQ(0, frame.data[7]);

    empty_canframe(frame);
    config->setValue("test1sig2", "2");
    config->getMessage("test1sig1")->assembleCANFrame(&frame);
    ASSERT_EQ(9, frame.data[0]);
    ASSERT_EQ(0, frame.data[1]);
    ASSERT_EQ(25, frame.data[2]);
    ASSERT_EQ(0, frame.data[3]);
    ASSERT_EQ(0, frame.data[4]);
    ASSERT_EQ(0, frame.data[5]);
    ASSERT_EQ(0, frame.data[6]);
    ASSERT_EQ(0, frame.data[7]);

    empty_canframe(frame);
    config->setValue("test1sig3", "1");
    config->getMessage("test1sig1")->assembleCANFrame(&frame);
    ASSERT_EQ(9, frame.data[0]);
    ASSERT_EQ(64, frame.data[1]);
    ASSERT_EQ(0, frame.data[2]);
    ASSERT_EQ(0, frame.data[3]);
    ASSERT_EQ(0, frame.data[4]);
    ASSERT_EQ(0, frame.data[5]);
    ASSERT_EQ(0, frame.data[6]);
    ASSERT_EQ(0, frame.data[7]);

    empty_canframe(frame);
    config->setValue("test1sig3", "1024");
    config->getMessage("test1sig1")->assembleCANFrame(&frame);
    ASSERT_EQ(9, frame.data[0]);
    ASSERT_EQ(0, frame.data[1]);
    ASSERT_EQ(0, frame.data[2]);
    ASSERT_EQ(1, frame.data[3]);
    ASSERT_EQ(0, frame.data[4]);
    ASSERT_EQ(0, frame.data[5]);
    ASSERT_EQ(0, frame.data[6]);
    ASSERT_EQ(0, frame.data[7]);

    empty_canframe(frame);
    config->getMessage("test2sig1")->assembleCANFrame(&frame);
    ASSERT_EQ(127, frame.data[0]);
    ASSERT_EQ(0, frame.data[1]);
    ASSERT_EQ(0, frame.data[2]);
    ASSERT_EQ(0, frame.data[3]);
    ASSERT_EQ(0, frame.data[4]);
    ASSERT_EQ(0, frame.data[5]);
    ASSERT_EQ(0, frame.data[6]);
    ASSERT_EQ(0, frame.data[7]);

    empty_canframe(frame);
    config->setValue("test2sig1", "1");
    config->getMessage("test2sig1")->assembleCANFrame(&frame);
    ASSERT_EQ(128, frame.data[0]);
    ASSERT_EQ(0, frame.data[1]);
    ASSERT_EQ(0, frame.data[2]);
    ASSERT_EQ(0, frame.data[3]);
    ASSERT_EQ(0, frame.data[4]);
    ASSERT_EQ(0, frame.data[5]);
    ASSERT_EQ(0, frame.data[6]);
    ASSERT_EQ(0, frame.data[7]);

    empty_canframe(frame);
    config->setValue("test2sig2", "1");
    config->getMessage("test2sig2")->assembleCANFrame(&frame);
    ASSERT_EQ(128, frame.data[0]);
    ASSERT_EQ(0, frame.data[1]);
    ASSERT_EQ(1, frame.data[2]);
    ASSERT_EQ(0, frame.data[3]);
    ASSERT_EQ(0, frame.data[4]);
    ASSERT_EQ(0, frame.data[5]);
    ASSERT_EQ(0, frame.data[6]);
    ASSERT_EQ(0, frame.data[7]);

    empty_canframe(frame);
    config->setValue("test2sig3", "8");
    config->getMessage("test2sig3")->assembleCANFrame(&frame);
    ASSERT_EQ(128, frame.data[0]);
    ASSERT_EQ(0, frame.data[1]);
    ASSERT_EQ(1, frame.data[2]);
    ASSERT_EQ(128, frame.data[3]);
    ASSERT_EQ(0, frame.data[4]);
    ASSERT_EQ(0, frame.data[5]);
    ASSERT_EQ(0, frame.data[6]);
    ASSERT_EQ(0, frame.data[7]);

    empty_canframe(frame);
    config->setValue("test2sig4", "2");
    config->getMessage("test2sig4")->assembleCANFrame(&frame);
    ASSERT_EQ(128, frame.data[0]);
    ASSERT_EQ(0, frame.data[1]);
    ASSERT_EQ(1, frame.data[2]);
    ASSERT_EQ(128, frame.data[3]);
    ASSERT_EQ(0, frame.data[4]);
    ASSERT_EQ(32, frame.data[5]);
    ASSERT_EQ(0, frame.data[6]);
    ASSERT_EQ(0, frame.data[7]);
}

TEST(LIB_canframe, test_parse) {
    Configuration *config = NULL;
    ASSERT_NO_THROW(config = new Configuration("tests.cfg", "tests.dbc"));
    canfd_frame frame;
    empty_canframe(frame);
    frame.can_id = 2;
    frame.data[0] = 129;
    ASSERT_TRUE(config->getMessage("test2sig1")->parseCANFrame(&frame, false));
    ASSERT_EQ(2, config->getSignal("test2sig1")->getValue().toInt());
    empty_canframe(frame);
    frame.can_id = 2;
    frame.data[2] = 2;
    ASSERT_TRUE(config->getMessage("test2sig2")->parseCANFrame(&frame, false));
    ASSERT_EQ(2, config->getSignal("test2sig2")->getValue().toInt());
    ASSERT_FALSE(config->getMessage("test2sig2")->parseCANFrame(&frame, false));
}


TEST(LIB_canframe, test_parse_assemble) {
    srand(testing::UnitTest::GetInstance()->random_seed());
    Configuration *config = NULL;
    ASSERT_NO_THROW(config = new Configuration("tests.cfg", "tests.dbc"));
    canfd_frame frame_in;

    empty_canframe(frame_in);
    frame_in.can_id = 1;
    frame_in.data[0] = rand() & 0xff;
    frame_in.data[1] = rand() & 0xff;
    frame_in.data[2] = rand() & 0xff;
    frame_in.data[3] = rand() & 0xff;
    ASSERT_TRUE(config->getMessage("test1sig1")->parseCANFrame(&frame_in, false));

    canfd_frame frame_out;
    empty_canframe(frame_out);
    config->getMessage("test1sig1")->assembleCANFrame(&frame_out);
    ASSERT_EQ(frame_out.can_id, frame_in.can_id);
    ASSERT_EQ(frame_out.data[0], frame_in.data[0]);
    ASSERT_EQ(frame_out.data[1], frame_in.data[1]);
    ASSERT_EQ(frame_out.data[2], frame_in.data[2]);
    ASSERT_EQ(frame_out.data[3], frame_in.data[3]);
    ASSERT_EQ(frame_out.data[4], frame_in.data[4]);
    ASSERT_EQ(frame_out.data[5], frame_in.data[5]);
    ASSERT_EQ(frame_out.data[6], frame_in.data[6]);
    ASSERT_EQ(frame_out.data[7], frame_in.data[7]);

    empty_canframe(frame_in);
    frame_in.can_id = 2;
    frame_in.data[0] = rand() & 0xff;
    frame_in.data[1] = rand() & 0xff;
    frame_in.data[2] = rand() & 0xff;
    frame_in.data[3] = rand() & 0xff;
    frame_in.data[4] = rand() & 0xff;
    frame_in.data[5] = rand() & 0xff;
    ASSERT_TRUE(config->getMessage("test2sig1")->parseCANFrame(&frame_in, false));
    empty_canframe(frame_out);
    config->getMessage("test2sig1")->assembleCANFrame(&frame_out);
    ASSERT_EQ(frame_out.can_id, frame_in.can_id);
    ASSERT_EQ(frame_out.data[0], frame_in.data[0]);
    ASSERT_EQ(frame_out.data[1], frame_in.data[1]);
    ASSERT_EQ(frame_out.data[2], frame_in.data[2]);
    ASSERT_EQ(frame_out.data[3], frame_in.data[3]);
    ASSERT_EQ(frame_out.data[4], frame_in.data[4]);
    ASSERT_EQ(frame_out.data[5], frame_in.data[5]);
    ASSERT_EQ(frame_out.data[6], frame_in.data[6]);
    ASSERT_EQ(frame_out.data[7], frame_in.data[7]);

    empty_canframe(frame_in);
    frame_in.can_id = 3;
    frame_in.data[0] = rand() & 0xff;
    frame_in.data[1] = rand() & 0xff;
    frame_in.data[2] = rand() & 0xff;
    frame_in.data[3] = rand() & 0xff;
    frame_in.data[4] = rand() & 0xff;
    ASSERT_TRUE(config->getMessage("test3sig1")->parseCANFrame(&frame_in, false));

    empty_canframe(frame_out);
    config->getMessage("test3sig1")->assembleCANFrame(&frame_out);
    ASSERT_EQ(frame_out.can_id, frame_in.can_id);
    ASSERT_EQ(frame_out.data[0], frame_in.data[0]);
    ASSERT_EQ(frame_out.data[1], frame_in.data[1]);
    ASSERT_EQ(frame_out.data[2], frame_in.data[2]);
    ASSERT_EQ(frame_out.data[3], frame_in.data[3]);
    ASSERT_EQ(frame_out.data[4], frame_in.data[4]);
    ASSERT_EQ(frame_out.data[5], frame_in.data[5]);
    ASSERT_EQ(frame_out.data[6], frame_in.data[6]);
    ASSERT_EQ(frame_out.data[7], frame_in.data[7]);
}

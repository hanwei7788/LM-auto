#*!
# \file
# \brief CMakeLists.txt foo
#
# Copyright of Link Motion Ltd. All rights reserved.
#
# Contact: info@link-motion.com
#
# \author Matti Lehtimäki <matti.lehtimaki@nomovok.com>
#
# any other legal text to be defined later

# Includes
include_directories(${CMAKE_CURRENT_SOURCE_DIR}
                    ${CMAKE_CURRENT_SOURCE_DIR}/../lib)

# Sources
file(GLOB SOURCES "*.cpp")

add_executable(${APPLICATION_NAME} ${SOURCES})

if (STATIC_BUILD)
set_target_properties(${APPLICATION_NAME} PROPERTIES LINK_FLAGS "-static -Wl,--whole-archive -lpthread -Wl,--no-whole-archive" )
endif()

target_link_libraries(${APPLICATION_NAME} lib${APPLICATION_NAME})

install(TARGETS ${APPLICATION_NAME}
        RUNTIME DESTINATION bin)

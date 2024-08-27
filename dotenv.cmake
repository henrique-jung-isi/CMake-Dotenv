cmake_minimum_required(VERSION 3.5)
# function(load_dotenv_file _file _headerFile)
# no arguments assumes:
#   .env = "${CMAKE_SOURCE_DIR}/.env"
#   default_values = "${CMAKE_SOURCE_DIR}/.env.example"
#   header = "${CMAKE_BINARY_DIR}/dotenv.h"
# arguments:
# READ - one value keyword - .env location
# VALUES - one value keyword - default values location
# HEADER - one value keyword - location to save header
# VALUES_LIST - multi value keyword - default values list specified by <var>=<value>
# NO_GENERATE_HEADER - option - does not generate a header file and only sets cmake variables
# NO_CONFIGURE_DEPENDS - option - does not create CONFIGURE_DEPENDS

function(load_dotenv_file)

    # cmake_parse_arguments(<prefix> <options> <one_value_keywords>
    #                       <multi_value_keywords> <args>...)
    set (options NO_GENERATE_HEADER NO_CONFIGURE_DEPENDS)
    set (one_value_keywords READ VALUES HEADER)
    set (multi_value_keywords VALUES_LIST)

    cmake_parse_arguments("ARGS" "${options}" "${one_value_keywords}" "${multi_value_keywords}" ${ARGN})

    # TODO: check for unparsed arguments
    message(CHECK_START "Resolving dotenv file")
    list(APPEND CMAKE_MESSAGE_INDENT "-- ")

    if(NOT DEFINED ARGS_READ)
        set(ARGS_READ "${CMAKE_SOURCE_DIR}/.env")
    endif()

    message(CHECK_START "Reading dotenv")
    check_file(${ARGS_READ} "")

    if(NOT DEFINED ARGS_VALUES)
        set(ARGS_VALUES "${ARGS_READ}.example")
    endif()

    if(NOT DEFINED ARGS_HEADER)
        set(ARGS_HEADER "${CMAKE_BINARY_DIR}/dotenv.h")
    endif()

    message(CHECK_START "Reading default values")
    if(NOT DEFINED ARGS_VALUES_LIST)
        check_file(${ARGS_VALUES} "File not found at")
    else()
        message(CHECK_PASS "Pass - List given")
    endif()

    if(NOT ARGS_NO_CONFIGURE_DEPENDS)
        get_directory_property(_depends CMAKE_CONFIGURE_DEPENDS)
        list(APPEND _depends ${ARGS_READ})
        if(NOT DEFINED ARGS_VALUES_LIST)
            list(APPEND _depends ${ARGS_VALUES})
        endif()
        list(REMOVE_DUPLICATES _depends)
        set_directory_properties(PROPERTIES CMAKE_CONFIGURE_DEPENDS "${_depends}")
    endif()

    if(NOT DEFINED ARGS_VALUES_LIST)
        file(STRINGS ${ARGS_VALUES} ARGS_VALUES_LIST)
    endif()

    set(_regularExpression "^([^=]+)=(.*)$")

    foreach (_line IN LISTS ARGS_VALUES_LIST)
        if (_line MATCHES ${_regularExpression})
            string(STRIP "${CMAKE_MATCH_1}" CMAKE_MATCH_1)
            string(STRIP "${CMAKE_MATCH_2}" CMAKE_MATCH_2)
            list(APPEND _defaultEnv ${CMAKE_MATCH_1})
            list(APPEND _defaultEnvValues "${CMAKE_MATCH_2}")
        endif()
    endforeach()

    if(EXISTS ${ARGS_READ})
    file(STRINGS ${ARGS_READ} _envFile)
        foreach (_line IN LISTS _envFile)
            if (_line MATCHES ${_regularExpression})
                string(STRIP "${CMAKE_MATCH_1}" CMAKE_MATCH_1)
                string(STRIP "${CMAKE_MATCH_2}" CMAKE_MATCH_2)
                list(APPEND _env ${CMAKE_MATCH_1})
                list(APPEND _envValues "${CMAKE_MATCH_2}")
            endif()
        endforeach()
    endif()

    # ----- Header generation -----
    if(NOT NO_GENERATE_HEADER)
        list(APPEND _headerContent "#ifndef DOT_ENV_H\n")
        list(APPEND _headerContent "#define DOT_ENV_H\n\n")
        list(APPEND _headerContent "#include <QVariant>\n\n")
        list(APPEND _headerContent "namespace Env {\n")
    endif()

    message(CHECK_START "Settings variables")
    list(APPEND CMAKE_MESSAGE_INDENT "-- ")
    set(_index 0)
    foreach (_defaultValue IN LISTS _defaultEnv)
        message(CHECK_START "${_defaultValue}")
        list(FIND _env ${_defaultValue} _varIndex)
        if(${_varIndex} GREATER "-1")
            list(GET _envValues ${_varIndex} _value)
            set(_pass true)
        else()
            list(GET _defaultEnvValues ${_index} _value)
            set(_pass false)
        endif()
        if(NOT "${_value}" MATCHES "^\"")
            set(_value "\"${_value}\"")
        endif()

        if(${_pass})
            message(CHECK_PASS ${_value})
        else()
            message(CHECK_FAIL "${_value} - default")
        endif()

        if(NOT NO_GENERATE_HEADER)
            list(APPEND _headerContent "const QVariant ${_defaultValue}(${_value})\;\n")
        endif()

        set(${_defaultValue} ${_value} PARENT_SCOPE)

        math(EXPR _index "${_index} + 1")
    endforeach()

    list(POP_BACK CMAKE_MESSAGE_INDENT)
    message(CHECK_PASS "Done")

    if(NOT NO_GENERATE_HEADER)
        list(APPEND _headerContent "}\n")
        list(APPEND _headerContent "\n#endif //DOT_ENV_H\n")
        file(WRITE ${ARGS_HEADER} ${_headerContent})
        message(STATUS "Dotenv header saved to ${ARGS_HEADER}")
    endif()

    list(POP_BACK CMAKE_MESSAGE_INDENT)

    if(EXISTS ${ARGS_READ})
        message(CHECK_PASS "Done")
    else()
        message(CHECK_FAIL "Done - default values used")
    endif()
endfunction()

macro(check_file _file _fail_message)
    file(REAL_PATH ${_file} _path)
    if(NOT EXISTS ${_path})
        message(CHECK_FAIL "Failed")
        if(NOT ${_fail_message} EQUAL "")
            message(FATAL_ERROR "${_fail_message} ${_path}")
        endif()
    else()
        message(CHECK_PASS "Done")
    endif()
endmacro()

#!/bin/sh
# Parses test EXIF files and compares the results to that expected
#
# Copyright (C) 2018-2021 Dan Fandrich <dan@coneharvesters.com>, et. al.
# SPDX-License-Identifier: LGPL-2.0-or-later

srcdir="${srcdir:-.}"
TMPLOG="$(mktemp)"
TMPEXP="$(mktemp)"
# test-parse writes its json and xml dumps to ${TEST_PARSE_DUMP_PREFIX}.json
# and .xml; a unique name, as tests can run in parallel in this directory
TEST_PARSE_DUMP_PREFIX="$(mktemp)"
export TEST_PARSE_DUMP_PREFIX
trap 'rm -f "${TMPLOG}" "${TMPEXP}" "${TEST_PARSE_DUMP_PREFIX}" "${TEST_PARSE_DUMP_PREFIX}.json" "${TEST_PARSE_DUMP_PREFIX}.xml"' 0

. ${srcdir}/inc-comparetool.sh

# Ensure that names are untranslated
LANG=
LANGUAGE=
LC_ALL=C
export LANG LANGUAGE LC_ALL
for fn in "${srcdir}"/testdata/*.jpg ; do
    rm -f "${TEST_PARSE_DUMP_PREFIX}.json" "${TEST_PARSE_DUMP_PREFIX}.xml"
    # The *.parsed text files have LF line endings, so the tr removes
    # the CR from CRLF line endings, while keeping LF line endings the
    # same.
    ./test-parse$EXEEXT "${fn}" | tr -d '\015' | sed -e 's/[[:space:]]*$//' > "${TMPLOG}"
    # Without EXIF_DATA_OPTION_FOLLOW_SPECIFICATION (not set by default in
    # this fork) blank-padded values such as UserComment are not fixed up,
    # so only compare up to trailing whitespace.
    sed -e 's/[[:space:]]*$//' "${fn}.parsed" > "${TMPEXP}"
    if ${comparetool} "${TMPEXP}" "${TMPLOG}"; then
	: "no differences detected"
    else
        echo "Error parsing $fn"
        exit 1
    fi

    # test-parse also dumps the data it parsed using the json and xml actions
    for kind in json xml ; do
        if test ! -f "${TEST_PARSE_DUMP_PREFIX}.${kind}" ; then
            echo "Could not find the ${kind} dump, needed to check the ${kind} dump action"
            exit 1
        fi
        if ${comparetool} "${fn}.${kind}" "${TEST_PARSE_DUMP_PREFIX}.${kind}"; then
            : "no differences detected"
        else
            echo "The ${kind} dump of $fn differs from ${fn}.${kind}"
            exit 1
        fi
    done
done

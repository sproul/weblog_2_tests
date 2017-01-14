#!/bin/bash
test_dir="$1"
if [ -z "$test_dir" ]; then
        t=/tmp/weblog_2_tests__last_test_dir
        if [ -f $t ]; then
                test_dir=`cat $t`
        else
                echo "$0: error: test_dir is a required arg" 1>&2
                exit 1
        fi
fi

Report()
{
        diff_fn="$1"
        test1_dir=`dirname "$diff_fn"`
        test_name=`basename "test1_dir"`
        original_server_url_fn=$test1_dir/original_server_url
        test_server_url_fn=$test1_dir/test_server_url
        if [ ! -f "$original_server_url_fn" ]; then
                echo "$0: error: could not find file \"original_server_url_fn\"" 1>&2
                exit 1
        fi
        rest_of_url=`cat $test1_dir/rest_of_url`
        original_url=`cat $original_server_url_fn`/$rest_of_url
        test_url=`cat $test_server_url_fn`/$rest_of_url
        cat <<EOF
        ===================================================
        Test $test_name
        Originally run against $original_url
        Tested against         $test_url
        diff output:
        `cat "$diff_fn" | sed -e 's/^/\t\t/'`
EOF
}


for diff in $test_dir/*/diff; do
        Report "$diff"
done
exit
$dp/rest_test_generator/weblog_2_tests/src/rest_test_report.sh 
#!/bin/bash
export PATH=`dirname $0`:$PATH
echo "ruby -wS rest_test_generator.rb $*"
ruby       -wS rest_test_generator.rb $*

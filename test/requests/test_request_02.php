<?php

foreach ($_REQUEST as $k => $v) {
    print "REQUEST[$k] => $v\n";
}

$_REQUEST = array_change_key_case($_REQUEST, CASE_UPPER);

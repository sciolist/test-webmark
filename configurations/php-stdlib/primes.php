<?php
for ($test=2; $test <= 10000; $test += 1) {
    for ($v=2; $v < $test; $v += 1) {
        if (($test % $v) === 0) continue 2;
    }
    echo "$test\n";
}

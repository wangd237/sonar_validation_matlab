function tests = test_propagation_coordinates
tests=functiontests(localfunctions);
end

function setupOnce(~)
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'propagation_model'));
end

function testLongRangeSinglePrecisionRoundingIsAccepted(testCase)
expected=(0:100:200000).';
legacy=double(single(expected));
legacy(1501)=legacy(1501)+0.015625;
verifyWarningFree(testCase,@() propagation_assert_same_coordinates( ...
    legacy,expected,'receiver range'));
end

function testMaterialGridDifferenceIsRejected(testCase)
expected=(0:100:200000).';
different=expected;
different(1501)=different(1501)+1;
verifyError(testCase,@() propagation_assert_same_coordinates( ...
    different,expected,'receiver range'),'propagation:Grid');
end

function testCoordinateCountDifferenceIsRejected(testCase)
verifyError(testCase,@() propagation_assert_same_coordinates( ...
    [0;100],[0;100;200],'receiver range'),'propagation:Grid');
end

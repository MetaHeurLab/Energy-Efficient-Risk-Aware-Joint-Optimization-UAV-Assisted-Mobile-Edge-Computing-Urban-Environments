function [lb,ub,dim,fobj,optimumValue] = Get_Functions_cec2022(F,dim)
% Official CEC2022 single-objective benchmark; existing four-output API retained.
% Source: P-N-Suganthan/2022-SO-BO, CEC2022 TR.pdf, benchmark definition table.
validateattributes(F,{'numeric'},{'scalar','integer','>=',1,'<=',12});
validateattributes(dim,{'numeric'},{'scalar','integer'});
assert(ismember(dim,[10 20]),'CEC2022:Dimension', ...
    'Use D=10 or D=20 for the complete twelve-function CEC2022 suite.');
lb = -100*ones(1,dim);
ub = 100*ones(1,dim);
optima = [300 400 600 800 900 1800 2000 2200 2300 2400 2600 2700];
optimumValue = optima(F);
fobj = @(x) cec22_func(x.',F);
end

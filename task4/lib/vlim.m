function [vmin, vmax] = vlim(kv)
% VLIM  정상시 전압 유지범위 [pu] - 「전력계통 신뢰도 및 전기품질 유지기준」 제6조
%   765·345 kV : ±5 %  (345 kV → 328~362 kV)
%   154 kV     : ±10 % (139~169 kV)
    vmin = 0.95 * ones(size(kv));  vmax = 1.05 * ones(size(kv));
    lo = kv < 345;
    vmin(lo) = 0.90;  vmax(lo) = 1.10;
end

function [add, nsteps] = greedy_reinforce(cgs, Ms, nl, maxit)
% GREEDY_REINFORCE  여러 시나리오를 동시에 만족할 때까지 1회선씩 증설 (그리디)
%   매 반복마다 각 시나리오에서 부하율이 가장 높은 선로에 1회선 추가 (n/(n+1) 방식)
%   ※ 최소 개수를 보장하는 최적화가 아니라 '부하율 높은 순' 휴리스틱
    if nargin < 4, maxit = 100; end
    add = zeros(nl, 1);  nsteps = 0;
    for it = 1:maxit
        worst = [];
        for s = 1:numel(cgs)
            [~, ~, R] = solve_add(cgs{s}, Ms{s}, add);
            if ~R.conv, add = nan(nl, 1); return; end
            if R.maxload > 100
                [~, k] = max(R.lp);  worst(end+1) = k; %#ok<AGROW>
            end
        end
        if isempty(worst), return; end
        for k = unique(worst), add(k) = add(k) + 1; end
        nsteps = nsteps + 1;
    end
end

function add = js_greedy(cc, qlim)
% JS_GREEDY  부하율이 가장 높은 선로부터 1회선씩 증설 (과부하가 없어질 때까지)
    if nargin < 2, qlim = false; end
    add = zeros(numel(cc.f), 1);
    for it = 1:100
        [~, ~, R] = js_solve(cc, add, qlim);
        if R.maxload <= 100, return; end
        [~, k] = max(R.lp);
        add(k) = add(k) + 1;
    end
end

function [res, cc, R] = js_solve(cc, add, qlim)
% JS_SOLVE  회선 증설(add) 반영 후 조류계산
    if nargin < 2 || isempty(add), add = zeros(numel(cc.f), 1); end
    if nargin < 3, qlim = false; end
    cc = add_circuits(cc, add);
    [res, cc] = pf_qlim(cc, qlim);
    fl = branch_flows(res.V, res.th, cc.f, cc.t, cc.r, cc.x, cc.b);
    R.lp = fl.Smax ./ cc.rate * 100;
    R.loss = sum(real(fl.loss)) * cc.baseMVA;
    R.nover = sum(R.lp > 100);  R.maxload = max(R.lp);
    R.conv = res.converged;
end

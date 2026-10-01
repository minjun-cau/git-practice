function [res, cc, R] = solve_add(cg, M, add)
% SOLVE_ADD  발전계획 cg + 대책 M(HVDC, STATCOM) + 회선 증설 add → 조류계산(Q 한계 적용)
    cc = build_kpg_case(apply_measures(cg, M));
    if nargin >= 3 && ~isempty(add), cc = add_circuits(cc, add); end
    [res, cc] = pf_qlim(cc, true);
    R.conv = res.converged && min(res.V) > 0.5 && max(res.V) < 1.5;
    if R.conv
        fl = branch_flows(res.V, res.th, cc.f, cc.t, cc.r, cc.x, cc.b);
        R.lp = fl.Smax ./ cc.rate * 100;
        R.loss = sum(real(fl.loss)) * cc.baseMVA;
        R.Vmin = min(res.V);  R.Vmax = max(res.V);
    else
        R.lp = inf(numel(cc.f), 1);  R.loss = inf;  R.Vmin = nan;  R.Vmax = nan;
    end
    R.nover = sum(R.lp > 100);  R.maxload = max(R.lp);
    R.V = res.V;
end

function [res, cc, S] = solve_future(cgen, M)
% SOLVE_FUTURE  발전계획이 정해진 케이스 + 대책 M → 조류계산 + 지표 계산
    cc = build_kpg_case(apply_measures(cgen, M));
    [res, cc] = pf_qlim(cc, true);
    S.conv = res.converged && min(res.V) > 0.5;
    if S.conv
        fl = branch_flows(res.V, res.th, cc.f, cc.t, cc.r, cc.x, cc.b);
        S.lp = fl.Smax ./ cc.rate * 100;
        S.loss = sum(real(fl.loss)) * cc.baseMVA;
    else
        S.lp = inf(numel(cc.f), 1);  S.loss = inf;
    end
    S.V = res.V;
end

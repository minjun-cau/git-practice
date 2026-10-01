function [res, fl, info] = run_case(c)
% RUN_CASE  케이스 구조체 c 로 Ybus 구성 → NR → 선로조류까지 한 번에
    Ybus = make_ybus(c.nb, c.f, c.t, c.r, c.x, c.b);
    res  = nr_pf(Ybus, c.type, c.Psp, c.Qsp, c.V0, c.th0, struct('maxit', 30));
    fl   = branch_flows(res.V, res.th, c.f, c.t, c.r, c.x, c.b);
    info.load_pct = fl.Smax ./ c.rate * 100;
    info.loss = sum(real(fl.loss));
    info.Vmin = min(res.V);  info.Vmax = max(res.V);
    info.maxload = max(info.load_pct);
end

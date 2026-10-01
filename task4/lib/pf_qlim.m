function [res, c, nsw] = pf_qlim(c, use_qlim)
% PF_QLIM  NR 조류계산 + 발전기 무효전력 한계 처리 (PV → PQ 전환)
%   PV 모선 발전기의 Q 가 Qmax/Qmin 을 넘으면 해당 모선을 PQ 로 바꾸고
%   Q 를 한계값으로 고정하여 다시 계산 (실제 계통에서 AVR 이 한계에 걸린 상황)
    if nargin < 2, use_qlim = true; end
    Ybus = make_ybus(c.nb, c.f, c.t, c.r, c.x, c.b);
    nsw = 0;
    V0 = c.V0;  th0 = c.th0;
    for rnd = 1:20
        res = nr_pf(Ybus, c.type, c.Psp, c.Qsp, V0, th0, struct('maxit', 30));
        if ~res.converged, warning('NR 미수렴'); break; end
        if ~use_qlim, break; end
        Qg = (res.Q + c.Qd / c.baseMVA) * c.baseMVA;   % 모선 발전기 무효전력 [MVar]
        pv = find(c.type == 2 & isfield_or(c));
        over  = pv(Qg(pv) > c.Qmax_bus(pv) + 1e-6);
        under = pv(Qg(pv) < c.Qmin_bus(pv) - 1e-6);
        if isempty(over) && isempty(under), break; end
        c.type([over; under]) = 3;
        c.Qsp(over)  = (c.Qmax_bus(over)  - c.Qd(over))  / c.baseMVA;
        c.Qsp(under) = (c.Qmin_bus(under) - c.Qd(under)) / c.baseMVA;
        nsw = nsw + numel(over) + numel(under);
        V0 = res.V;  th0 = res.th;
    end
    res.Qg_bus = (res.Q + c.Qd / c.baseMVA) * c.baseMVA;
end

function m = isfield_or(c)
% STATCOM 등 Q 한계를 따로 두지 않는 모선은 한계 처리에서 제외
    m = true(c.nb, 1);
    if isfield(c, 'extra_pv'), m(c.extra_pv) = false; end
end

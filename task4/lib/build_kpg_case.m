function c = build_kpg_case(c)
% BUILD_KPG_CASE  발전기/부하로부터 조류계산 입력(type, Psp, Qsp, V0) 구성
%   - 한 모선의 운전 중 발전기 Pg 를 합산
%   - 운전 발전기가 없는 PV 모선은 PQ 로 처리
%   - PV/Slack 모선 전압은 발전기 Vg 사용
    nb = c.nb;  on = c.gon;
    Pg_bus = accumarray(c.gbus(on), c.Pg(on), [nb 1]);
    c.Qmax_bus = accumarray(c.gbus(on), c.Qmax(on), [nb 1]);
    c.Qmin_bus = accumarray(c.gbus(on), c.Qmin(on), [nb 1]);
    hasgen = accumarray(c.gbus(on), 1, [nb 1]) > 0;

    c.type = c.type0;
    c.type(c.type == 2 & ~hasgen) = 3;
    c.type(hasgen & c.type == 3) = 2;      % 발전기가 새로 투입된 PQ 모선
    if isfield(c, 'extra_pv')              % STATCOM 등 추가 전압제어 모선
        c.type(c.extra_pv) = 2;
    end

    c.Psp = (Pg_bus - c.Pd) / c.baseMVA;
    c.Qsp = -c.Qd / c.baseMVA;
    if isfield(c, 'Pinj_extra'), c.Psp = c.Psp + c.Pinj_extra / c.baseMVA; end

    c.V0 = ones(nb, 1);  c.th0 = zeros(nb, 1);
    Vg_bus = accumarray(c.gbus(on), c.Vg(on), [nb 1], @max);
    c.V0(hasgen) = Vg_bus(hasgen);
    if isfield(c, 'extra_pv'), c.V0(c.extra_pv) = c.extra_pv_V; end
    c.th0 = c.Va_init * pi/180;            % 데이터의 각도를 초기값으로 사용
end

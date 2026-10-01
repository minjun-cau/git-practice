function [c, info] = build_2032(c0, S, snap, cf)
% BUILD_2032  KPG193 에 2032년 시나리오(scen2032) 반영 + 급전 → 발전계획이 정해진 케이스
%   snap : 'peak' (여름 최대부하) 또는 'light' (봄 낮 경부하)
%   cf   : (선택) 재생E 출력 비율 struct('solar',..,'wind',..) - 감도분석용
    if nargin < 4, cf = S.cf.(snap); end
    c = c0;
    pf_q = tan(acos(0.98));                       % 신규 부하 역률 0.98

    %% 1) 수요
    pos = c.Pd > 0;
    L0  = sum(c.Pd(pos));
    T_peak = L0 * S.peak_scale;                   % 2032 최대부하 (기존 + 신규 포함)
    add = zeros(c.nb, 1);
    for k = 1:size(S.yongin_load, 1)
        add(S.yongin_load(k,1)) = add(S.yongin_load(k,1)) + S.yongin_load(k,2);
    end
    dc_m = S.dc_total * S.dc_metro_share / numel(S.dc_metro_bus);
    dc_o = S.dc_total * (1 - S.dc_metro_share) / numel(S.dc_other_bus);
    add(S.dc_metro_bus) = add(S.dc_metro_bus) + dc_m;
    add(S.dc_other_bus) = add(S.dc_other_bus) + dc_o;
    E = sum(add);                                 % 반도체·데이터센터 : 24시간 거의 일정한 부하
    if strcmp(snap, 'peak'), T = T_peak; else, T = S.light_ratio * T_peak; end
    k_load = (T - E) / L0;                        % 나머지 부하 배율
    c.Pd(pos) = c.Pd(pos) * k_load;
    c.Qd(pos) = c.Qd(pos) * k_load;
    c.Pd = c.Pd + add;
    c.Qd = c.Qd + add * pf_q;

    %% 2) 재생E 증가분 (Negative PQ, 역률 1)
    re = zeros(c.nb, 1);
    sol = S.solar_add * cf.solar;
    sjn = sol * S.solar_share.jeonnam;  sjb = sol * S.solar_share.jeonbuk;
    srest = sol - sjn - sjb;
    re(S.solar_jn_bus) = re(S.solar_jn_bus) + sjn / numel(S.solar_jn_bus);
    re(S.solar_jb_bus) = re(S.solar_jb_bus) + sjb / numel(S.solar_jb_bus);
    w = -c0.Pd(S.solar_rest_bus);  w = w / sum(w);
    re(S.solar_rest_bus) = re(S.solar_rest_bus) + srest * w;
    wnd = S.wind_add * cf.wind;
    for k = 1:size(S.wind_alloc, 1)
        re(S.wind_alloc(k,1)) = re(S.wind_alloc(k,1)) + wnd * S.wind_alloc(k,2);
    end

    %% 3) 발전설비 : 석탄 → LNG 전환, 용인 LNG
    for k = 1:size(S.coal_conv, 1)
        b = S.coal_conv(k,1);  X = S.coal_conv(k,2);
        m = c.gbus == b & strcmp(c.fuel, 'Coal');
        tot = sum(c.Pmax(m));
        sc = max(0, 1 - X / tot);                 % 남는 석탄 비율
        c.Pmax(m) = c.Pmax(m) * sc;  c.Pmin(m) = c.Pmin(m) * sc;  c.Pg(m) = c.Pg(m) * sc;
        c.Qmax(m) = c.Qmax(m) * sc;  c.Qmin(m) = c.Qmin(m) * sc;
        if ~ismember(b, S.coal_relocate(:,1))     % 같은 부지 LNG 전환
            c = newgen(c, b, X, 'LNG');
        end
    end
    for k = 1:size(S.yongin_lng, 1)
        c = newgen(c, S.yongin_lng(k,1), S.yongin_lng(k,2), 'LNG');
    end
    % Slack(사천) 발전기는 항상 운전 (계통 주파수·전압 기준)
    c.mustrun = c.gbus == find(c.type0 == 1);

    %% 4) 수급 균형 : 경직성 발전(원전 최소출력 + must-run)이 수요보다 크면 재생E 출력제어
    rank_n = strcmp(c.fuel, 'Nuclear');
    D_net = (sum(c.Pd) - sum(re)) * 1.01;
    must = sum(c.Pmin(c.gon & (rank_n | c.mustrun)));
    curtail = 0;
    if must > D_net
        curtail = min(sum(re), (must - D_net) / 1.01);
        re = re * (1 - curtail / sum(re));
    end
    c.Pd = c.Pd - re;
    c = dispatch_kpg(c, 1.0);

    info.k_load = k_load;  info.T = T;  info.E = E;
    info.re_MW = sum(re);  info.re = re;  info.curtail_MW = curtail;
    info.solar_MW = sol;  info.wind_MW = wnd;
    fu = {'Nuclear', 'Coal', 'LNG'};
    for k = 1:3
        m = c.gon & strcmp(c.fuel, fu{k});
        info.gen.(fu{k}) = sum(c.Pg(m));
    end
end

function c = newgen(c, b, P, fuel)
    c.gbus(end+1,1) = b;  c.Pg(end+1,1) = 0;
    c.Qmax(end+1,1) = 0.5*P;  c.Qmin(end+1,1) = -0.5*P;
    c.Vg(end+1,1) = 1.04;  c.gon(end+1,1) = true;
    c.Pmax(end+1,1) = P;  c.Pmin(end+1,1) = 0.38*P;
    c.fuel{end+1,1} = fuel;
    if isfield(c, 'mustrun'), c.mustrun(end+1,1) = false; end
end

function c = future_kpg(c, F)
% FUTURE_KPG  미래 계통 변화 반영 (부하 증가, AI 부하, 재생E, 석탄 폐지, 신규 원전 등)
%   F.load_scale : 기존 일반부하 배율
%   F.ai         : [모선, 추가부하 MW] - 데이터센터/반도체 (역률 0.98)
%   F.re         : [모선, 재생E 출력 MW] - Negative PQ 로 반영
%   F.retire     : 폐지할 발전기 조건 {모선 목록, 연료}
%   F.newgen     : [모선, Pmax, Pmin, 연료코드(1 원자력 2 석탄 3 LNG)]
    fu = {'Nuclear', 'Coal', 'LNG'};
    pos = c.Pd > 0;
    c.Pd(pos) = c.Pd(pos) * F.load_scale;
    c.Qd(pos) = c.Qd(pos) * F.load_scale;

    if isfield(F, 'ai')
        for k = 1:size(F.ai, 1)
            b = F.ai(k,1);  P = F.ai(k,2);
            c.Pd(b) = c.Pd(b) + P;
            c.Qd(b) = c.Qd(b) + P * tan(acos(0.98));
        end
    end
    if isfield(F, 're')
        for k = 1:size(F.re, 1)
            c.Pd(F.re(k,1)) = c.Pd(F.re(k,1)) - F.re(k,2);
        end
    end
    if isfield(F, 'retire')
        m = ismember(c.gbus, F.retire{1}) & strcmp(c.fuel, F.retire{2});
        keep = ~m;
        c.gbus = c.gbus(keep); c.Pg = c.Pg(keep); c.Qmax = c.Qmax(keep); c.Qmin = c.Qmin(keep);
        c.Vg = c.Vg(keep); c.gon = c.gon(keep); c.Pmax = c.Pmax(keep); c.Pmin = c.Pmin(keep);
        c.fuel = c.fuel(keep);
    end
    if isfield(F, 'newgen')
        for k = 1:size(F.newgen, 1)
            g = F.newgen(k,:);
            c.gbus(end+1,1) = g(1);  c.Pg(end+1,1) = g(2);
            c.Qmax(end+1,1) = 0.5*g(2);  c.Qmin(end+1,1) = -0.5*g(2);
            c.Vg(end+1,1) = 1.04;  c.gon(end+1,1) = true;
            c.Pmax(end+1,1) = g(2);  c.Pmin(end+1,1) = g(3);
            c.fuel{end+1,1} = fu{g(4)};
        end
    end
end

function c = apply_measures(c, M)
% APPLY_MEASURES  계통 보강 대책 반영 (build_kpg_case 전에 호출)
%   M.hvdc    : [송전모선 수전모선 P_MW 손실률]  - VSC-HVDC (양단 전압제어, 기본 1.03 pu)
%   M.dup     : 증설(병행 회선 추가)할 기존 선로 번호
%   M.statcom : [모선 V_set]  - STATCOM/동기조상기 (무효전력으로 전압 유지)
    c.Pinj_extra = zeros(c.nb, 1);
    c.extra_pv = [];  c.extra_pv_V = [];
    if isfield(M, 'hvdc')
        for k = 1:size(M.hvdc, 1)
            h = M.hvdc(k,:);
            c.Pinj_extra(h(1)) = c.Pinj_extra(h(1)) - h(3);
            c.Pinj_extra(h(2)) = c.Pinj_extra(h(2)) + h(3) * (1 - h(4));
            c.extra_pv   = [c.extra_pv;   h(1); h(2)];
            Vh = 1.03; if isfield(M, 'hvdc_V'), Vh = M.hvdc_V; end
            c.extra_pv_V = [c.extra_pv_V; Vh; Vh];
        end
    end
    if isfield(M, 'dup') && ~isempty(M.dup)
        d = M.dup(:);
        c.f = [c.f; c.f(d)];  c.t = [c.t; c.t(d)];
        c.r = [c.r; c.r(d)];  c.x = [c.x; c.x(d)];  c.b = [c.b; c.b(d)];
        c.rate = [c.rate; c.rate(d)];  c.br_kv = [c.br_kv; c.br_kv(d)];
    end
    if isfield(M, 'statcom') && ~isempty(M.statcom)
        c.extra_pv   = [c.extra_pv;   M.statcom(:,1)];
        c.extra_pv_V = [c.extra_pv_V; M.statcom(:,2)];
    end
    % 같은 모선이 중복 지정되면 첫 번째 값 사용
    [c.extra_pv, iu] = unique(c.extra_pv, 'first');
    c.extra_pv_V = c.extra_pv_V(iu);
end

function cc = js_case(c, opt)
% JS_CASE  자소서 해석용 케이스 (용인 데이터센터 4 GW)
%   opt.dc    : 데이터센터 추가 여부 (21 동용인, 23 서용인 각 2,000 MW + 400 Mvar)
%   opt.hvdc  : 강릉(1) 4,000 MW 추출 → 서용인(23) 3,880 MW 주입 (변환손실 3 %, 부하로 단순화)
%   opt.share : 늘어난 수요를 'slack'(기준 모선) 또는 'all'(운전 발전기 Pg 비례)이 공급
%   opt.scale : 부하·발전 배율 (경부하 0.6)
%   133번 세종 : 운전 발전기는 없지만 연구실 자료처럼 PV(P = 0, V = 1.00 pu)로 유지
    if ~isfield(opt, 'share'), opt.share = 'slack'; end
    if ~isfield(opt, 'scale'), opt.scale = 1; end
    c.Pd = c.Pd * opt.scale;  c.Qd = c.Qd * opt.scale;  c.Pg = c.Pg * opt.scale;
    extra = 0;
    if opt.dc
        c.Pd([21 23]) = c.Pd([21 23]) + 2000;
        c.Qd([21 23]) = c.Qd([21 23]) + 400;
        extra = extra + 4000;
    end
    c.Pinj_extra = zeros(c.nb, 1);
    if opt.hvdc
        c.Pinj_extra(1)  = -4000;
        c.Pinj_extra(23) = 3880;
        extra = extra + 120;
    end
    if strcmp(opt.share, 'all')          % 증가분을 운전 발전기가 출력 비례로 분담
        on = c.gon;
        c.Pg(on) = c.Pg(on) * (1 + extra / sum(c.Pg(on)));
    end
    if isfield(opt, 'statcom'), c.extra_pv = opt.statcom(1); c.extra_pv_V = opt.statcom(2); end
    cc = build_kpg_case(c);
    cc.type(133) = 2;  cc.V0(133) = 1.00;
end

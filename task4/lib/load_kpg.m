function c = load_kpg(datadir)
% LOAD_KPG  KPG193 (194모선) MATPOWER 케이스를 조류계산용 구조체로 변환
%   MATPOWER 모선 type : 1=PQ, 2=PV, 3=Slack  →  본 코드 : 1=Slack, 2=PV, 3=PQ
    addpath(datadir);
    mpc = KPG193_test;
    b = mpc.bus;  g = mpc.gen;  br = mpc.branch;

    c.baseMVA = mpc.baseMVA;           % 100 MVA
    c.nb = size(b, 1);
    if any(b(:,1) ~= (1:c.nb)'), error('bus 번호가 1..nb 순서가 아님'); end
    map = [3 2 1];                     % MATPOWER type -> 1 Slack, 2 PV, 3 PQ
    c.type0 = map(b(:,2))';
    c.Pd = b(:,3);  c.Qd = b(:,4);     % [MW, MVar]
    c.kv = b(:,10);  c.area = b(:,7);
    c.Vm_init = b(:,8);  c.Va_init = b(:,9);

    % 발전기 (정지 발전기도 남겨두고 status 로 구분)
    c.gbus = g(:,1);  c.Pg = g(:,2);  c.Qmax = g(:,4);  c.Qmin = g(:,5);
    c.Vg = g(:,6);  c.gon = g(:,8) == 1;  c.Pmax = g(:,9);  c.Pmin = g(:,10);
    c.fuel = gen_fuel(fullfile(datadir, 'KPG193_test.m'), size(g,1));

    % 선로 : b 는 전체 충전 서셉턴스 (양 끝 b/2), rateA [MVA]
    c.f = br(:,1); c.t = br(:,2); c.r = br(:,3); c.x = br(:,4); c.b = br(:,5);
    c.rate = br(:,6) / c.baseMVA;      % [pu]
    c.br_kv = max(c.kv(c.f), c.kv(c.t));
    c.ncir = branch_circuits(fullfile(datadir, 'KPG193_test.m'), size(br,1));   % 행 끝 주석의 회선 수

    % 위치 / 이름
    fid = fopen(fullfile(datadir, 'bus_location.csv'), 'r', 'n', 'UTF-8');
    fgetl(fid);
    C = textscan(fid, '%f %f %f %s %s', 'Delimiter', ',', 'Whitespace', '');
    fclose(fid);
    c.lat = C{2};  c.lon = C{3};  c.name_kr = C{4};  c.name = C{5};

    % 지역(area) 이름 : 각 area 안의 'OO본부직할' 모선 이름에서 추출
    na = max(c.area);
    c.area_name = cell(na, 1);
    for a = 1:na
        idx = find(c.area == a);
        c.area_name{a} = sprintf('area%d', a);
        for k = idx'
            s = c.name_kr{k};
            p = strfind(s, '본부직할');
            if ~isempty(p), c.area_name{a} = s(1:p(1)-1); break; end
        end
    end
end

function n = branch_circuits(fname, nl)
% 선로 행 끝 주석(% 전압 line 회선수)에서 등가 선로에 묶인 회선 수 추출
    txt = fileread(fname);
    s = strfind(txt, 'mpc.branch = [');
    e = strfind(txt(s:end), '];');
    lines = strsplit(txt(s:s+e(1)), sprintf('\n'));
    n = [];
    for k = 2:numel(lines)
        L = strtrim(lines{k});
        if isempty(L) || L(1) == '%' || L(1) == ']', continue; end
        tk = regexp(L, '(\d+)\s*$', 'tokens');
        n(end+1,1) = str2double(tk{1}{1}); %#ok<AGROW>
    end
    if numel(n) ~= nl, error('선로 회선 수 정보 개수 불일치'); end
end

function fuel = gen_fuel(fname, ng)
% 발전기 행 끝의 주석(% Coal / LNG / Nuclear)으로 연료 구분
    txt = fileread(fname);
    s = strfind(txt, 'mpc.gen = [');
    e = strfind(txt(s:end), '];');
    blk = txt(s:s+e(1));
    lines = strsplit(blk, sprintf('\n'));
    fuel = {};
    for k = 2:numel(lines)
        L = strtrim(lines{k});
        if isempty(L) || L(1) == '%' || L(1) == ']', continue; end
        p = strfind(L, '%');
        fuel{end+1,1} = strtrim(L(p(end)+1:end)); %#ok<AGROW>
    end
    if numel(fuel) ~= ng, error('발전기 연료 정보 개수 불일치'); end
end

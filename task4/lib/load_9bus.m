function c = load_9bus(datadir)
% LOAD_9BUS  대한민국 간소화 9모선 데이터(Bus.dat, Line.dat) 읽기
    B = load(fullfile(datadir, 'Bus.dat'));   % Num Type PG QG PL QL VM VAngle
    L = load(fullfile(datadir, 'Line.dat'));  % From To R X B(전체)
    c.baseMVA = 30000;  c.baseKV = 345;
    c.nb   = size(B, 1);
    c.type = B(:,2);
    c.PG = B(:,3); c.QG = B(:,4); c.PL = B(:,5); c.QL = B(:,6);
    c.Psp = c.PG - c.PL;          % 순 주입전력 = 발전 - 부하
    c.Qsp = c.QG - c.QL;          % (신재생 6, 9번은 PL<0 → 주입)
    c.V0  = B(:,7);  c.th0 = B(:,8) * pi/180;
    c.f = L(:,1); c.t = L(:,2); c.r = L(:,3); c.x = L(:,4); c.b = L(:,5);
    c.rate = ones(size(L,1), 1);  % 선로 허용용량 1 pu = 30 GW (과제 가정)
    c.name = {'Gyeongnam','Gangwon','Seoul','Jeonbuk','Gyeongbuk', ...
              'Jeonnam','Chungbuk','Gyeonggi','Chungnam'};
    c.name_kr = {'경남','강원','서울','전북','경북','전남','충북','경기','충남'};
    % 계통도 그림용 지역 위치 (실제 지도를 단순화한 좌표, [x y])
    c.xy = [128.6 35.1; 128.6 37.8; 126.9 37.9; 127.2 35.8; 128.9 36.3; ...
            126.7 34.9; 128.0 36.9; 127.6 37.35; 126.6 36.6];
end

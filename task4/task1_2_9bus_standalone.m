function task1_2_9bus_standalone()
%% Task 1-2 : 대한민국 간소화 9모선 AC 조류해석 (단독 실행 버전)
%   이 파일 하나와 같은 폴더의 Bus.dat, Line.dat (+ 정답 .mat 3개)만 있으면 실행됩니다.
%   실행 : MATLAB 명령창에서  task1_2_9bus_standalone
%
%   Step 0. System Interpretation  : Bus.dat, Line.dat 읽기
%   Step 1. PU                     : S base 30 GVA, V base 345 kV, Z base 3.9675 Ohm
%   Step 2. Finding Ybus           : pi 등가회로 (양 끝에 B/2)
%   Step 3. Bus typing             : 1 Slack, 2 PV, 3 PQ
%   Step 4~5. Newton-Raphson       : 불일치 → 자코비안 → 갱신 (각도는 rad)
%            Gauss-Seidel          : 비교용
%   Step 6. Result                 : 실제 단위 환산, 허용전압, 선로 부하율·손실
%   Step 7. Plotting               : 수렴 특성, 모선 전압, 선로 부하율

clc;
dd = fileparts(mfilename('fullpath'));            % 이 파일이 있는 폴더
if exist(fullfile(dd, 'Bus.dat'), 'file') ~= 2    % 저장소 구조(task4/data)도 지원
    dd = fullfile(dd, 'data');
end

%% Step 0. System Interpretation
Bus  = load(fullfile(dd, 'Bus.dat'));    % Num Type PG QG PL QL VM VAngle  [pu]
Line = load(fullfile(dd, 'Line.dat'));   % From To R X B(전체 충전 서셉턴스) [pu]
nb = size(Bus, 1);
name = {'경남','강원','서울','전북','경북','전남','충북','경기','충남'};

%% Step 1. PU
Sbase = 30;               % [GVA]  (30,000 MVA)
Vbase = 345;              % [kV]
Zbase = Vbase^2 / (Sbase*1000);   % 345^2 / 30000 = 3.9675 Ohm
Vmin = 0.95;  Vmax = 1.05;        % 345 kV 허용범위 (전기품질 유지기준 제6조: 328~362 kV)
rate = 1;                         % 선로 허용용량 1 pu = 30 GW (과제 가정)

%% Step 2. Finding Ybus
f = Line(:,1);  t = Line(:,2);  r = Line(:,3);  x = Line(:,4);  b = Line(:,5);
Ybus = zeros(nb);
for k = 1:size(Line, 1)
    y   = 1 / (r(k) + 1j*x(k));       % 직렬 어드미턴스
    ysh = 1j * b(k) / 2;              % Line.dat 의 B 는 전체 값 → 양 끝에 B/2
    Ybus(f(k),f(k)) = Ybus(f(k),f(k)) + y + ysh;
    Ybus(t(k),t(k)) = Ybus(t(k),t(k)) + y + ysh;
    Ybus(f(k),t(k)) = Ybus(f(k),t(k)) - y;
    Ybus(t(k),f(k)) = Ybus(t(k),f(k)) - y;
end
ref = load(fullfile(dd, 'Y_bus_example.mat'));
fprintf('[Step 2] Ybus 정답 대비 최대 오차 = %.2e\n', max(abs(Ybus(:) - ref.Y(:))));

%% Step 3. Bus typing
type = Bus(:,2);                      % 1 Slack, 2 PV, 3 PQ
Psp  = Bus(:,3) - Bus(:,5);           % 주입 P = PG - PL  (신재생은 PL<0 → 주입)
Qsp  = Bus(:,4) - Bus(:,6);           % 주입 Q = QG - QL
V0   = Bus(:,7);
th0  = Bus(:,8) * pi/180;             % 각도는 rad 로 계산

%% Step 4~5. Newton-Raphson
[V, th, itNR, histNR] = newton_raphson(Ybus, type, Psp, Qsp, V0, th0, 1e-8, 20);
fprintf('[Step 4~5] Newton-Raphson : %d 회 반복 후 수렴\n', itNR);

% Gauss-Seidel (비교용)
[Vg, thg, itGS,  histGS ] = gauss_seidel(Ybus, type, Psp, Qsp, V0, th0, 1e-8, 5000, 1.0);
[~,  ~,   itGSa, histGSa] = gauss_seidel(Ybus, type, Psp, Qsp, V0, th0, 1e-8, 5000, 1.6);
fprintf('            Gauss-Seidel   : %d 회 (가속계수 1.0), %d 회 (가속계수 1.6)\n', itGS, itGSa);
fprintf('            NR-GS 최대 전압 차이 = %.2e pu\n', max(abs(V.*exp(1j*th) - Vg.*exp(1j*thg))));

Vref = load(fullfile(dd, 'V_mag_example.mat'));
Aref = load(fullfile(dd, 'V_angle_example.mat'));
fprintf('            정답 대비 최대 오차 : |V| %.2e pu, 각도 %.2e rad\n', ...
    max(abs(V - Vref.Vmag_result(:))), max(abs(th - Aref.Angle_result(:))));

%% Step 6. Result
[P, Q] = bus_power(Ybus, V, th);
tn = {'Slack','PV','PQ'};
fprintf('\n[Step 6] 모선 결과 (실제 단위)\n');
fprintf('Bus 지역  종류   |V|[pu]  |V|[kV]  각도[deg]  P주입[GW]  Q주입[GVar]  판정\n');
for k = 1:nb
    s = 'OK';
    if V(k) < Vmin, s = '저전압'; elseif V(k) > Vmax, s = '과전압'; end
    fprintf('%3d %-4s %-5s  %7.4f  %7.1f  %9.3f  %9.3f  %10.3f   %s\n', k, name{k}, tn{type(k)}, ...
        V(k), V(k)*Vbase, th(k)*180/pi, P(k)*Sbase, Q(k)*Sbase, s);
end

% 선로 조류 : I_ij = y(V_i - V_j) + (jB/2)V_i,  S_ij = V_i conj(I_ij),  손실 = S_ij + S_ji
Vc  = V .* exp(1j*th);
y   = 1 ./ (r + 1j*x);   ysh = 1j*b/2;
Sij = Vc(f) .* conj(y.*(Vc(f) - Vc(t)) + ysh.*Vc(f));
Sji = Vc(t) .* conj(y.*(Vc(t) - Vc(f)) + ysh.*Vc(t));
loss = Sij + Sji;
loading = max(abs(Sij), abs(Sji)) / rate * 100;     % 부하율 [%] (양 끝 피상전력 중 큰 값)

fprintf('\n[Step 6] 선로 결과\n');
fprintf('선로   R[Ohm]  X[Ohm]   P[GW]   Q[GVar]  |S|[GVA]  부하율[%%]  손실[MW]\n');
for k = 1:numel(f)
    fprintf('%d-%d  %7.3f %7.3f  %7.2f  %7.2f  %8.2f  %8.1f  %8.1f\n', f(k), t(k), r(k)*Zbase, x(k)*Zbase, ...
        real(Sij(k))*Sbase, imag(Sij(k))*Sbase, max(abs(Sij(k)), abs(Sji(k)))*Sbase, loading(k), ...
        real(loss(k))*Sbase*1000);
end
PL = Bus(:,5);
fprintf('총 유효전력 손실 = %.1f MW (부하의 %.2f %%)\n', sum(real(loss))*Sbase*1000, ...
    sum(real(loss)) / sum(PL(PL > 0)) * 100);
[mx, im] = max(loading);
fprintf('최대 부하율 = %.1f %% (선로 %d-%d), 100 %% 초과 %d개, 전압 위반 모선 %s\n', mx, f(im), t(im), ...
    sum(loading > 100), mat2str(find(V < Vmin | V > Vmax)'));

%% Step 7. Plotting
figure('position', [100 100 1300 420]);
subplot(1, 3, 1);
semilogy(0:itNR, histNR, 'o-', 'linewidth', 2); hold on;
semilogy(0:itGS, histGS, '-', 'linewidth', 1.5);
semilogy(0:itGSa, histGSa, '-', 'linewidth', 1.5);
grid on; xlabel('Iteration'); ylabel('max |mismatch| [pu]');
legend('Newton-Raphson', 'Gauss-Seidel \alpha=1.0', 'Gauss-Seidel \alpha=1.6');
title('수렴 특성');

subplot(1, 3, 2);
bar(V, 0.6); hold on;
plot([0.5 nb+0.5], [Vmin Vmin], 'r--', [0.5 nb+0.5], [Vmax Vmax], 'r--', 'linewidth', 1.5);
set(gca, 'xtick', 1:nb, 'xticklabel', name); ylim([0.85 1.10]); grid on;
ylabel('|V| [pu]'); title('모선 전압 (허용 0.95~1.05 pu)');

subplot(1, 3, 3);
bar(loading, 0.6, 'facecolor', [0.9 0.55 0.2]); hold on;
plot([0.5 numel(f)+0.5], [100 100], 'r--', 'linewidth', 1.5);
lbl = arrayfun(@(k) sprintf('%d-%d', f(k), t(k)), 1:numel(f), 'uniformoutput', false);
set(gca, 'xtick', 1:numel(f), 'xticklabel', lbl); grid on;
ylabel('부하율 [%] (1 pu = 30 GW)'); title('선로 부하율');
end


%% ===================== 보조 함수 =====================
function [P, Q] = bus_power(Ybus, V, th)
% 모선 주입전력  S = V .* conj(Ybus * V)
    Vc = V .* exp(1j*th);
    S  = Vc .* conj(Ybus * Vc);
    P  = real(S);  Q = imag(S);
end

function [V, th, it, hist] = newton_raphson(Ybus, type, Psp, Qsp, V, th, tol, maxit)
% 극좌표 Newton-Raphson
%   미지수 x = [th(PV,PQ); V(PQ)],  불일치 f = [dP(PV,PQ); dQ(PQ)],  dx = J \ f
    n = numel(type);
    pv = find(type == 2);  pq = find(type == 3);  pvpq = [pv; pq];  m = numel(pvpq);
    hist = zeros(maxit+1, 1);
    for it = 0:maxit
        [P, Q] = bus_power(Ybus, V, th);
        dP = Psp - P;  dQ = Qsp - Q;
        fm = [dP(pvpq); dQ(pq)];
        hist(it+1) = max(abs(fm));
        if hist(it+1) < tol, break; end

        % 자코비안 (원소별 식)
        G = real(Ybus);  B = imag(Ybus);
        J1 = zeros(n); J2 = zeros(n); J3 = zeros(n); J4 = zeros(n);   % dP/dth dP/dV dQ/dth dQ/dV
        for i = 1:n
            for k = 1:n
                a = th(i) - th(k);
                if i ~= k
                    J1(i,k) =  V(i)*V(k)*( G(i,k)*sin(a) - B(i,k)*cos(a));
                    J2(i,k) =  V(i)     *( G(i,k)*cos(a) + B(i,k)*sin(a));
                    J3(i,k) = -V(i)*V(k)*( G(i,k)*cos(a) + B(i,k)*sin(a));
                    J4(i,k) =  V(i)     *( G(i,k)*sin(a) - B(i,k)*cos(a));
                end
            end
            J1(i,i) = -Q(i) - B(i,i)*V(i)^2;
            J2(i,i) =  P(i)/V(i) + G(i,i)*V(i);
            J3(i,i) =  P(i) - G(i,i)*V(i)^2;
            J4(i,i) =  Q(i)/V(i) - B(i,i)*V(i);
        end
        J = [J1(pvpq,pvpq) J2(pvpq,pq); J3(pq,pvpq) J4(pq,pq)];

        dx = J \ fm;
        th(pvpq) = th(pvpq) + dx(1:m);        % rad 그대로 더함
        V(pq)    = V(pq)    + dx(m+1:end);
    end
    hist = hist(1:it+1);
end

function [V, th, it, hist] = gauss_seidel(Ybus, type, Psp, Qsp, V0, th0, tol, maxit, alpha)
% Gauss-Seidel :  V_i <- (1/Y_ii) [ (P_i - jQ_i)/conj(V_i) - sum_{k~=i} Y_ik V_k ]
%   PV 모선은 Q 를 현재 전압으로 계산한 뒤 각도만 갱신(크기 고정), alpha = 가속계수
    n = numel(type);
    Vc = V0 .* exp(1j*th0);  Q = Qsp;
    hist = zeros(maxit+1, 1);
    for it = 0:maxit
        S = Vc .* conj(Ybus * Vc);
        dP = Psp - real(S);  dQ = Qsp - imag(S);
        hist(it+1) = max(abs([dP(type ~= 1); dQ(type == 3)]));
        if hist(it+1) < tol, break; end
        for i = 1:n
            if type(i) == 1, continue; end
            sumYV = Ybus(i,:) * Vc - Ybus(i,i) * Vc(i);
            if type(i) == 2
                Q(i) = -imag(conj(Vc(i)) * (Ybus(i,:) * Vc));
            end
            Vnew = ((Psp(i) - 1j*Q(i)) / conj(Vc(i)) - sumYV) / Ybus(i,i);
            if type(i) == 2
                Vc(i) = V0(i) * exp(1j*angle(Vnew));
            else
                Vc(i) = Vc(i) + alpha * (Vnew - Vc(i));
            end
        end
    end
    V = abs(Vc);  th = angle(Vc);  hist = hist(1:it+1);
end

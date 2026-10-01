%% Task 1-1 : Bergen 예제 10.6 (3모선) Newton-Raphson 조류계산
%  가이드 코드(ac3bus.m)를 정리한 버전
%   - 각도는 라디안으로 계산 (가이드 코드의 도/라디안 혼용 문제 해결)
%   - PQ/PV 인덱스를 find() 로 처리 → 모선 순서와 무관하게 동작
clear; clc;
addpath(fullfile(fileparts(mfilename('fullpath')), 'lib'));
dd = fullfile(fileparts(mfilename('fullpath')), 'data');

Line = csvread(fullfile(dd, '3bus_line.csv'), 1, 0);   % From To R X yC(=b/2)
Bus  = csvread(fullfile(dd, '3bus_bus.csv'),  1, 0);   % bus V P Q theta Type
nb = size(Bus, 1);

% 3bus.xlsx 의 yC 는 '한쪽 끝' 서셉턴스(b/2) → 전체 b = 2*yC
Ybus = make_ybus(nb, Line(:,1), Line(:,2), Line(:,3), Line(:,4), 2*Line(:,5));

type = Bus(:,6);  V0 = Bus(:,2);  th0 = Bus(:,5)*pi/180;
Psp  = Bus(:,3);  Qsp = Bus(:,4);

fprintf('=== Task 1-1 : 3모선 (Bergen Ex.10.6) ===\n');
disp('Ybus ='); disp(full(Ybus));

res = nr_pf(Ybus, type, Psp, Qsp, V0, th0, struct('verbose', true));
fprintf('\nNR 수렴 반복횟수 : %d\n', res.iter);
fprintf(' Bus     |V| [pu]   theta [deg]    P [pu]     Q [pu]\n');
for k = 1:nb
    fprintf(' %3d   %9.4f   %10.4f   %9.4f  %9.4f\n', k, res.V(k), res.th_deg(k), res.P(k), res.Q(k));
end

% 가이드 코드와 같은 조건(tol=1e-4)에서 도/라디안 버그 영향 비교
r1 = nr_pf(Ybus, type, Psp, Qsp, V0, th0, struct('tol', 1e-4));
fprintf('\n[참고] tol=1e-4 에서 라디안으로 올바르게 업데이트 시 반복횟수 = %d\n', r1.iter);

gs = gs_pf(Ybus, type, Psp, Qsp, V0, th0);
fprintf('Gauss-Seidel 반복횟수 = %d,  NR 과 최대 전압차 = %.2e pu\n', ...
        gs.iter, max(abs(gs.V.*exp(1j*gs.th) - res.V.*exp(1j*res.th))));

T = [(1:nb)' res.V res.th_deg res.P res.Q];
outdir = fullfile(fileparts(mfilename('fullpath')), 'results');
if ~exist(outdir, 'dir'), mkdir(outdir); end
fid = fopen(fullfile(outdir, 'task1_1_3bus.csv'), 'w');
fprintf(fid, 'bus,V_pu,theta_deg,P_pu,Q_pu\n');
fprintf(fid, '%d,%.6f,%.6f,%.6f,%.6f\n', T');
fclose(fid);

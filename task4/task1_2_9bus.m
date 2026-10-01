%% Task 1-2 : 대한민국 간소화 9모선 조류해석 (NR 필수 + Gauss-Seidel)
%   1) Ybus 계산 → Y_bus_example.mat 과 비교
%   2) NR / GS 조류계산 → V_mag_example, V_angle_example 과 비교
%   3) p.u. → 실제 단위(kV, GW, GVar, Ohm) 환산, 허용전압범위 확인
%   4) 선로별 부하율(1 pu = 30 GW)과 손실
clear; clc;
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'lib'));
dd = fullfile(root, 'data');  outdir = fullfile(root, 'results');
if ~exist(outdir, 'dir'), mkdir(outdir); end

c = load_9bus(dd);

%% 1) Ybus
Ybus = make_ybus(c.nb, c.f, c.t, c.r, c.x, c.b);
ref = load(fullfile(dd, 'Y_bus_example.mat'));
fprintf('=== Task 1-2 : 9모선 ===\n');
fprintf('Ybus 최대 오차 (정답 대비) = %.2e\n', max(abs(full(Ybus(:)) - ref.Y(:))));

%% 2) NR / GS
nr = nr_pf(Ybus, c.type, c.Psp, c.Qsp, c.V0, c.th0, struct('verbose', true));
fprintf('NR : %d 회 반복 후 수렴 (tol 1e-8)\n', nr.iter);
gs  = gs_pf(Ybus, c.type, c.Psp, c.Qsp, c.V0, c.th0, struct('alpha', 1.0));
gsa = gs_pf(Ybus, c.type, c.Psp, c.Qsp, c.V0, c.th0, struct('alpha', 1.6));
fprintf('GS : %d 회 (가속계수 1.0), %d 회 (가속계수 1.6)\n', gs.iter, gsa.iter);
fprintf('GS-NR 최대 전압 차이 = %.2e pu\n', max(abs(gs.V.*exp(1j*gs.th) - nr.V.*exp(1j*nr.th))));

Vref = load(fullfile(dd, 'V_mag_example.mat'));  Aref = load(fullfile(dd, 'V_angle_example.mat'));
fprintf('정답 대비 최대 오차 : |V| %.2e pu,  angle %.2e rad\n', ...
    max(abs(nr.V - Vref.Vmag_result(:))), max(abs(nr.th - Aref.Angle_result(:))));

% 수렴 특성 그림
fig = figure('visible', 'off', 'position', [0 0 700 420]);
semilogy(0:nr.iter, nr.mismatch, 'o-', 'linewidth', 2); hold on;
semilogy(0:gs.iter, gs.mismatch, '-', 'linewidth', 1.5);
semilogy(0:gsa.iter, gsa.mismatch, '-', 'linewidth', 1.5);
grid on; xlabel('Iteration'); ylabel('max |mismatch| [pu]');
legend(sprintf('Newton-Raphson (%d it)', nr.iter), sprintf('Gauss-Seidel a=1.0 (%d it)', gs.iter), ...
       sprintf('Gauss-Seidel a=1.6 (%d it)', gsa.iter));
title('9-bus convergence'); xlim([0 max(gs.iter, 10)]);
print(fig, '-dpng', '-r110', fullfile(outdir, 'task1_2_convergence.png')); close(fig);

%% 3), 4) 실제 단위 환산 + 전압/부하율/손실
out = report_9bus(c, nr, 'Task 1-2: 9-bus base case (NR)', outdir, 'task1_2_9bus');
save(fullfile(outdir, 'task1_2_result.mat'), 'c', 'nr', 'out');

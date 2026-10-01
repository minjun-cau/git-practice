%% Task 1-5 : 대한민국 상세화 계통에 미래 환경 반영 후 조류해석
%   미래 변화 (lib/future_def.m 에 정의한 가정값)
%     (1) AI·반도체 신규부하 10 GW : 용인 반도체 클러스터 6 GW + 수도권 데이터센터 4 GW
%     (2) 재생E 23 GW 추가 : 신안·해남·영암·영광·새만금·부안 등 서남해안 집중
%     (3) 충남 석탄 폐지 11 GW (보령·태안) → 태안 LNG 2 GW 전환
%     (4) 신규 원전 2.8 GW (울진 신한울 3·4호기), 용인 클러스터 LNG 3 GW
%   시나리오
%     미래 최대부하 : 기존 부하 ×1.15 + AI 10 GW, 재생E 40 % 출력 (여름 저녁)
%     미래 경부하   : 기존 부하 ×0.60 + AI 10 GW, 재생E 100 % 출력 (봄철 낮)
clear; clc;
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'lib'));
dd = fullfile(root, 'data');  outdir = fullfile(root, 'results');
c0 = load_kpg(dd);
P4 = load(fullfile(outdir, 'task1_4_result.mat'));   % 현재 계통 결과 (비교용)

%% (A) 미래 최대부하
F = future_def('peak');
c = dispatch_kpg(future_kpg(c0, F), 1.0);
cc = build_kpg_case(c);
[res, cc, nsw] = pf_qlim(cc, true);
fprintf('[미래 최대부하] 수렴=%d, PV→PQ 전환 %d개\n', res.converged, nsw);
Speak = summarize_kpg(cc, res, 'Task 1-5: 미래 최대부하 (AI +10 GW)', outdir, 'task1_5_future_peak');
fut.peak.c = cc;  fut.peak.res = res;  fut.peak.S = Speak;

%% (B) 미래 경부하 - 재생E 100 % 출력
F = future_def('light');
c = dispatch_kpg(future_kpg(c0, F), 1.0);
cc = build_kpg_case(c);
[res, cc] = pf_qlim(cc, true);
fprintf('\n[미래 경부하, 재생E 23 GW 전량] 수렴 = %d  → ', res.converged);
if ~res.converged
    fprintf('조류계산 해가 존재하지 않음 (전압붕괴)\n');
end

%% (C) 신안 해상풍력 수용 한계 : P-V 곡선 (출력을 조금씩 늘리며 연속 계산)
%   다른 재생E 는 100 % 출력, 신안(154 kV) 출력만 0 → 5 GW 증가
Fl = future_def('light');
ish = find(Fl.re(:,1) == 89);
Pgrid = 0:100:5000;
Vsh = nan(size(Pgrid));  Vmin_sys = nan(size(Pgrid));  maxld = nan(size(Pgrid));
Vsh_q = nan(size(Pgrid));  ok_q = false(size(Pgrid));
[vmn, vmx] = vlim(c0.kv);        % 345 kV 이상 ±5 %, 154 kV ±10 % (신안 154 kV → 하한 0.90 pu)
Vw = [];  thw = [];  nose = false;
for k = 1:numel(Pgrid)
    Fk = Fl;  Fk.re(ish, 2) = Pgrid(k);
    ck = build_kpg_case(dispatch_kpg(future_kpg(c0, Fk), 1.0));
    % (1) 무효전력 한계 없이, 직전 해에서 출발 → 전압붕괴점(nose)까지 추적
    if ~nose
        Yk = make_ybus(ck.nb, ck.f, ck.t, ck.r, ck.x, ck.b);
        if isempty(Vw), Vw = ck.V0;  thw = ck.th0; end
        V0 = Vw;  V0(ck.type ~= 3) = ck.V0(ck.type ~= 3);
        rk = nr_pf(Yk, ck.type, ck.Psp, ck.Qsp, V0, thw, struct('maxit', 30));
        if ~rk.converged || min(rk.V) < 0.5
            nose = true;
        else
            Vw = rk.V;  thw = rk.th;
            Vsh(k) = rk.V(89);  Vmin_sys(k) = min(rk.V);
            flk = branch_flows(rk.V, rk.th, ck.f, ck.t, ck.r, ck.x, ck.b);
            maxld(k) = max(flk.Smax ./ ck.rate * 100);
        end
    end
    % (2) 발전기 무효전력 한계 적용 (실제 운전 조건) → 허용범위 만족 여부
    [rq, ~] = pf_qlim(ck, true);
    if rq.converged && min(rq.V) > 0.5
        Vsh_q(k) = rq.V(89);
        ok_q(k) = all(rq.V >= vmn & rq.V <= vmx);
    end
end
klim = find(~isnan(Vsh), 1, 'last');
Plim = Pgrid(klim);
fprintf('신안 154 kV 모선 재생E 수용 한계 ≈ %.1f GW (그 이상은 해 없음), 이때 신안 전압 %.3f pu\n', ...
    Plim/1000, Vsh(klim));

fig = figure('visible', 'off', 'position', [0 0 760 440]);
plot(Pgrid/1000, Vsh, 'o-', 'linewidth', 2); hold on; grid on;
plot(Pgrid/1000, Vsh_q, 'd-', 'linewidth', 1.5);
plot([0 5], [0.90 0.90], 'r--');
if klim < numel(Pgrid)
    plot([Plim Plim]/1000, [0.5 1.1], 'k:', 'linewidth', 1.5);
    text(Plim/1000 + 0.05, 0.62, {'조류계산 해 없음', '(전압붕괴)'}, 'fontsize', 9);
end
xlabel('신안 해상풍력 출력 [GW]'); ylabel('신안 모선 |V| [pu]'); ylim([0.55 1.1]); xlim([0 5]);
legend('무효전력 한계 미적용', '발전기 무효전력 한계 적용', '154 kV 허용 하한 0.90 pu', 'location', 'southwest');
title('미래 경부하 : 신안(154 kV) 재생E 수용 한계 (P-V 곡선)');
print(fig, '-dpng', '-r110', fullfile(outdir, 'task1_5_pv_curve.png')); close(fig);

%% (D) 미래 경부하 - 허용전압을 지키는 최대 출력으로 제한 운전
%   무효전력 한계를 적용한 상태에서 모든 모선이 허용범위(345 kV↑ ±5 %, 154 kV ±10 %) 안인 최대 출력
kop = find(~ok_q, 1) - 1;
if isempty(kop), kop = numel(Pgrid); end
Pop = Pgrid(max(kop, 1));
fprintf('→ 운전 가능 출력 %.1f GW 로 제한 (출력제한량 %.1f GW, 무효전력 한계 적용 시 신안 %.3f pu)\n', ...
    Pop/1000, (5000 - Pop)/1000, Vsh_q(max(kop, 1)));
Fl.re(ish, 2) = Pop;
c = dispatch_kpg(future_kpg(c0, Fl), 1.0);
cc = build_kpg_case(c);
[res, cc] = pf_qlim(cc, true);
Slight = summarize_kpg(cc, res, sprintf('Task 1-5: 미래 경부하 (신안 %.1f GW로 출력제한)', Pop/1000), ...
                       outdir, 'task1_5_future_light');
fut.light.c = cc;  fut.light.res = res;  fut.light.S = Slight;  fut.light.Plim = Plim;  fut.light.Pop = Pop;
fut.pv = struct('P', Pgrid, 'Vsh', Vsh, 'Vsh_q', Vsh_q, 'ok_q', ok_q, 'Vmin', Vmin_sys, 'maxload', maxld);
save(fullfile(outdir, 'task1_5_result.mat'), 'fut');

%% (E) 현재 vs 미래 비교
fprintf('\n===== 현재 vs 미래 =====\n');
fprintf('%-26s 수요[GW] 재생E[GW] 손실[MW]  Vmin   Vmax  최대부하율 과부하선로\n', '');
rows = {'현재 중부하', P4.R(2).S; '미래 최대부하', Speak; '현재 경부하', P4.R(3).S; '미래 경부하(출력제한)', Slight};
for k = 1:size(rows, 1)
    S = rows{k,2};
    fprintf('%-26s %7.1f %8.1f %8.0f  %5.3f  %5.3f  %7.0f %%  %5d\n', rows{k,1}, S.load_GW, S.re_GW, ...
        S.loss_MW, S.Vmin, S.Vmax, S.maxload, S.n100);
end

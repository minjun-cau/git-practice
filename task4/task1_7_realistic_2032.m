%% Task 1-5/1-6 (현실 조건판) : 공식 자료 기반 2032년 계통 조류해석과 보강 대책
%   Task 1-5/1-6 은 가정값(AI 10 GW, 재생E 23 GW 등)으로 미래를 만들었음.
%   이 스크립트는 공식 계획 수치(lib/scen2032.m, 항목별 출처 기재)로 2032년 계통을 구성:
%     - 수요 : 11차 전기본 연 1.8 % 증가, 봄철 최저 = 최대의 40 %
%     - 용인 반도체 산단 1단계 3 GW + 산단 LNG 1 GW×3, 데이터센터 2.5 GW (68 % 수도권)
%     - 재생E : 11차 전기본 2030·2038 목표를 2032로 보간 (태양광 61.1, 풍력 23.9 GW)
%     - 석탄 18기 9.1 GW LNG 전환, HVDC 3개 링크 (동해안→신가평·동서울 각 4 GW, 새만금→서화성 2 GW)
%   해석 기준 (더 엄밀하게)
%     - 발전기 무효전력 한계 적용 (PV→PQ 전환)
%     - 증설은 등가 선로의 회선 수 n 을 읽어 1회선씩: r,x ×n/(n+1), b·정격 ×(n+1)/n
%     - 경직성 발전(원전 최소출력)이 수요보다 크면 재생E 출력제어
%     - HVDC 송전량은 계통 혼잡이 최소가 되도록 운영 (25 % 단위 탐색)
clear; clc;
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'lib'));
dd = fullfile(root, 'data');  outdir = fullfile(root, 'results');
c0 = load_kpg(dd);
S  = scen2032();
nl = numel(c0.f);
snaps = {'peak', 'light'};  snap_kr = {'2032 여름 최대부하', '2032 봄 낮 경부하'};
none = struct('hvdc', zeros(0,4), 'statcom', zeros(0,2));

%% 1) 시나리오 요약
fprintf('=== 2032년 시나리오 (공식 자료 기반) ===\n');
fprintf('최대부하 배율 %.3f (연 %.1f %% × %d년) | 경부하 = 최대의 %.0f %%\n', S.peak_scale, ...
    S.growth_rate*100, S.years, S.light_ratio*100);
fprintf('재생E 2032 : 태양광 %.1f GW (+%.1f), 풍력 %.1f GW (+%.1f)\n', S.solar_2032, S.solar_add/1000, ...
    S.wind_2032, S.wind_add/1000);
fprintf('용인 산단 %.1f GW, 데이터센터 %.2f GW (수도권 %.0f %%)\n', sum(S.yongin_load(:,2))/1000, ...
    S.dc_total/1000, S.dc_metro_share*100);
src = {S.growth_src; S.light_src; S.yongin_src; S.dc_src; S.re_src; S.solar_share_src; S.wind_src; ...
       S.cf_src; S.coal_src; S.nuke_src; S.hvdc_src};
fprintf('출처:\n');  fprintf('  - %s\n', src{:});

%% 2) 시나리오별 조류계산 : HVDC 없음 vs 계획 HVDC(혼잡 최소 운전)
cg = cell(1, 2);  Mh = cell(1, 2);  info = cell(1, 2);
fprintf('\n=== 시나리오별 결과 ===\n');
for s = 1:2
    [cg{s}, info{s}] = build_2032(c0, S, snaps{s});
    I = info{s};
    fprintf('\n[%s] 수요 %.1f GW (반도체·DC %.1f GW 포함) | 재생E 증가분 출력 %.1f GW, 출력제어 %.1f GW\n', ...
        snap_kr{s}, I.T/1000, I.E/1000, I.re_MW/1000, I.curtail_MW/1000);
    fprintf('   발전: 원전 %.1f, 석탄 %.1f, LNG %.1f GW\n', I.gen.Nuclear/1000, I.gen.Coal/1000, I.gen.LNG/1000);
    [~, ~, R0] = solve_add(cg{s}, none, []);
    [P, R1] = best_hvdc(cg{s}, S.hvdc, 0:0.25:1);
    Mh{s} = struct('hvdc', [S.hvdc(:,1:2) P S.hvdc(:,4)], 'statcom', zeros(0,2));
    if R0.conv
        fprintf('   HVDC 없음      : 과부하 %2d개, 최대 %5.0f %%, 전압 %.3f~%.3f, 손실 %.0f MW\n', ...
            R0.nover, R0.maxload, R0.Vmin, R0.Vmax, R0.loss);
    else
        fprintf('   HVDC 없음      : 해 없음 (전압붕괴)\n');
    end
    fprintf('   계획 HVDC 운전 : 과부하 %2d개, 최대 %5.0f %%, 전압 %.3f~%.3f, 손실 %.0f MW  (송전량 %s MW)\n', ...
        R1.nover, R1.maxload, R1.Vmin, R1.Vmax, R1.loss, mat2str(P'));
    res_tab(s,:) = {R0, R1, P}; %#ok<SAGROW>
    [res, cc] = solve_add(cg{s}, Mh{s}, []);
    summarize_kpg(cc, res, ['2032 현실 조건: ' snap_kr{s} ' (계획 HVDC)'], outdir, ['task1_7_' snaps{s}]);
end

%% 3) 원인 확인 : 경부하의 '해 없음'은 송전 용량이 아니라 무효전력 부족
%   경부하에는 화력이 거의 모두 정지 → 전압을 잡아줄 발전기가 사라짐
term = unique(S.hvdc(:,1:2));
fprintf('\n=== 경부하 해 없음의 원인 ===\n');
cc = build_kpg_case(apply_measures(cg{2}, none));
r_noq = pf_qlim(cc, false);
fprintf('발전기 무효전력 한계를 풀면 수렴 = %d  → 무효전력(전압 지원) 부족이 원인\n', r_noq.converged);
for b = term'
    [~, ~, Rb] = solve_add(cg{2}, struct('hvdc', zeros(0,4), 'statcom', [b 1.03]), []);
    fprintf('  HVDC 없이 %s 에 STATCOM 1개소만 → 수렴 = %d\n', c0.name_kr{b}, Rb.conv);
end

%% 4) 대안별 필요 증설 회선 (그리디, n/(n+1)) : 두 시나리오를 모두 만족
fprintf('\n=== 대안별 필요 증설 ===\n');
a0p = greedy_reinforce(cg(1), {none}, nl);
fprintf('(최대부하만) 증설만                 : %2d회선\n', sum(a0p));
% HVDC 운전점을 '증설 회선 최소' 기준으로 탐색 (최대부하)
bestn = inf;  bestP = [];
for a = 0:0.25:1, for b = 0:0.25:1, for d = 0:0.5:1
    P = [S.hvdc(1,3)*a; S.hvdc(2,3)*b; S.hvdc(3,3)*d];
    M = struct('hvdc', [S.hvdc(:,1:2) P S.hvdc(:,4)], 'statcom', zeros(0,2));
    ad = greedy_reinforce(cg(1), {M}, nl, 40);
    if ~any(isnan(ad)) && sum(ad) < bestn, bestn = sum(ad); bestP = P; end
end, end, end
fprintf('(최대부하만) 계획 HVDC(회선 최소 운전) : %2d회선  (송전량 %s MW)\n', bestn, mat2str(bestP'));

% 두 시나리오 동시 : (A) STATCOM 1개소 + 증설  vs  (B) 계획 HVDC(혼잡 최소 운전) + 증설
bestA = inf;
for b = term'
    Ms = struct('hvdc', zeros(0,4), 'statcom', [b 1.03]);
    ad = greedy_reinforce(cg, {Ms, Ms}, nl);
    if sum(ad) < bestA, bestA = sum(ad); addA = ad; MA = Ms; end
end
addB = greedy_reinforce(cg, Mh, nl);
fprintf('(두 시나리오) STATCOM 1개소(%s) + 증설 : %2d회선\n', c0.name_kr{MA.statcom(1)}, bestA);
list_add(c0, addA);
fprintf('(두 시나리오) 계획 HVDC + 증설          : %2d회선\n', sum(addB));
list_add(c0, addB);
add_h = addA;

for s = 1:2
    [res, cc, R] = solve_add(cg{s}, MA, addA);
    [vmn, vmx] = vlim(cc.kv);
    bad = find(res.V < vmn | res.V > vmx);
    fprintf('[%s] STATCOM+증설 후 : 과부하 %d개, 최대 %.0f %%, 전압 %.3f~%.3f, 손실 %.0f MW, 전압위반 %d개\n', ...
        snap_kr{s}, R.nover, R.maxload, R.Vmin, R.Vmax, R.loss, numel(bad));
    summarize_kpg(cc, res, ['2032 현실 조건: ' snap_kr{s} ' 보강 후'], outdir, ['task1_7_' snaps{s} '_final']);
end

%% 5) 감도분석 : 재생E 출력 비율(가장 불확실한 가정)을 바꿔도 결론이 유지되는가
fprintf('\n=== 감도분석 (재생E 출력 비율, 시나리오 단독) ===\n');
sens = {'peak',  struct('solar', 0.00, 'wind', 0.15), '최대부하, 태양광 0 %';
        'peak',  struct('solar', 0.30, 'wind', 0.15), '최대부하, 태양광 30 %';
        'peak',  struct('solar', 0.15, 'wind', 0.35), '최대부하, 풍력 35 %';
        'light', struct('solar', 0.55, 'wind', 0.25), '경부하, 태양광 55 %';
        'light', struct('solar', 0.85, 'wind', 0.25), '경부하, 태양광 85 %';
        'light', struct('solar', 0.70, 'wind', 0.40), '경부하, 풍력 40 %'};
fprintf('%-22s 출력제어[GW]  보상없음      STATCOM+증설   HVDC+증설\n', '');
for k = 1:size(sens, 1)
    [cgk, Ik] = build_2032(c0, S, sens{k,1}, sens{k,2});
    [~, ~, R0] = solve_add(cgk, none, []);
    aA = greedy_reinforce({cgk}, {MA}, nl);
    [Pk] = best_hvdc(cgk, S.hvdc, 0:0.5:1);
    aB = greedy_reinforce({cgk}, {struct('hvdc', [S.hvdc(:,1:2) Pk S.hvdc(:,4)], 'statcom', zeros(0,2))}, nl);
    if R0.conv, s0 = sprintf('과부하 %2d개', R0.nover); else, s0 = '해 없음    '; end
    fprintf('%-22s %8.1f      %s    %3d회선       %3d회선\n', sens{k,3}, Ik.curtail_MW/1000, s0, sum(aA), sum(aB));
end

save(fullfile(outdir, 'task1_7_result.mat'), 'S', 'res_tab', 'addA', 'addB', 'MA', 'bestP', 'info');


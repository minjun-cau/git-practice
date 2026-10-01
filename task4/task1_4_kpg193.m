%% Task 1-4 : 대한민국 상세화(KPG193, 194모선) 조류해석 - 기본/중부하/경부하
%   - 9모선과 같은 NR 함수(lib/nr_pf.m)를 그대로 사용 (sparse 자코비안)
%   - 한 모선에 여러 발전기 → Pg 합산, status=0 발전기 제외, PV 전압은 Vg
%   - 발전기 무효전력 한계(Qmax/Qmin) 초과 시 PV→PQ 전환 (lib/pf_qlim.m)
%
%   부하 시나리오 (과제에 구체적 수치가 없어 아래처럼 가정)
%     기본부하 : 데이터 그대로 (수요 84.2 GW, 주어진 발전 계획)
%     중부하   : 일반부하 ×1.15 (≈97 GW, 2024.8 여름 최대전력 97.1 GW 수준)
%     경부하   : 일반부하 ×0.60 (≈50 GW, 봄·가을 새벽 최저수요 수준)
%     → 중/경부하는 급전순위(원자력→석탄→LNG)로 발전 재배분 (lib/dispatch_kpg.m)
clear; clc;
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'lib'));
dd = fullfile(root, 'data');  outdir = fullfile(root, 'results');

c0 = load_kpg(dd);
scen = {'기본부하', 1.00, 'task1_4_base';
        '중부하',   1.15, 'task1_4_heavy';
        '경부하',   0.60, 'task1_4_light'};

R = struct();
for s = 1:size(scen, 1)
    if scen{s,2} == 1
        c = c0;                              % 주어진 발전 계획 그대로
    else
        c = dispatch_kpg(c0, scen{s,2});
    end
    cc = build_kpg_case(c);
    [res, cc, nsw] = pf_qlim(cc, true);
    fprintf('\n[%s] 무효전력 한계로 PV→PQ 전환된 모선 %d개, 수렴=%d\n', scen{s,1}, nsw, res.converged);
    S = summarize_kpg(cc, res, ['Task 1-4: KPG193 ' scen{s,1}], outdir, scen{s,3});
    R(s).name = scen{s,1};  R(s).c = cc;  R(s).res = res;  R(s).S = S;
end
save(fullfile(outdir, 'task1_4_result.mat'), 'R');

fprintf('\n===== Task 1-4 요약 =====\n');
fprintf('%-8s  수요[GW]  손실[MW]  Vmin   Vmax   V위반  최대부하율  과부하선로\n', '');
for s = 1:numel(R)
    S = R(s).S;
    fprintf('%-8s  %7.1f  %8.0f  %5.3f  %5.3f  %4d   %7.0f %%  %6d\n', R(s).name, S.load_GW, S.loss_MW, ...
        S.Vmin, S.Vmax, S.nlow + S.nhigh, S.maxload, S.n100);
end

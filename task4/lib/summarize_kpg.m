function S = summarize_kpg(c, res, label, outdir, tag)
% SUMMARIZE_KPG  194모선 결과 요약 출력 + CSV/그림 저장
    Sb = c.baseMVA;
    fl = branch_flows(res.V, res.th, c.f, c.t, c.r, c.x, c.b);
    lp = fl.Smax ./ c.rate * 100;
    Pg_bus = res.P * Sb + c.Pd;                  % 모선 발전 [MW] (Slack 포함, HVDC 등 추가주입 포함)
    if isfield(c, 'Pinj_extra'), Pg_bus = Pg_bus - c.Pinj_extra; end

    S.label = label;
    S.load_GW = sum(c.Pd(c.Pd > 0)) / 1000;
    S.re_GW = -sum(c.Pd(c.Pd < 0)) / 1000;
    S.gen_GW = sum(Pg_bus(c.type ~= 3 | Pg_bus > 1)) / 1000;
    S.loss_MW = sum(real(fl.loss)) * Sb;
    S.Vmin = min(res.V);  S.Vmax = max(res.V);
    [vmn, vmx] = vlim(c.kv);                     % 345 kV 이상 ±5 %, 154 kV ±10 %
    S.nlow = sum(res.V < vmn);  S.nhigh = sum(res.V > vmx);
    S.maxload = max(lp);  S.n100 = sum(lp > 100);  S.n80 = sum(lp > 80);
    S.slack_MW = Pg_bus(c.type == 1);
    S.iter = res.iter;
    S.lp = lp;  S.fl = fl;

    fprintf('\n===== %s =====\n', label);
    fprintf('수요 %.1f GW (재생E %.1f GW 별도) | 송전손실 %.0f MW (%.2f %%) | Slack(사천) %.0f MW | NR %d회\n', ...
        S.load_GW, S.re_GW, S.loss_MW, S.loss_MW / (S.load_GW*1000) * 100, S.slack_MW, S.iter);
    fprintf('전압 %.3f ~ %.3f pu | 허용범위(345 kV↑ ±5 %%, 154 kV ±10 %%) 미만 %d개, 초과 %d개\n', S.Vmin, S.Vmax, S.nlow, S.nhigh);
    fprintf('최대 부하율 %.0f %% | 100 %% 초과 %d개, 80 %% 초과 %d개 선로\n', S.maxload, S.n100, S.n80);

    fprintf('  지역          부하[GW]  발전[GW]  순유입[GW]  Vmin    Vmax\n');
    na = max(c.area);
    for a = 1:na
        idx = c.area == a;
        Ld = sum(c.Pd(idx)) / 1000;  G = sum(Pg_bus(idx)) / 1000;
        fprintf('  %-12s %8.2f  %8.2f  %9.2f  %6.3f  %6.3f\n', c.area_name{a}, Ld, G, Ld - G, ...
            min(res.V(idx)), max(res.V(idx)));
    end
    [~, ix] = sort(lp, 'descend');
    fprintf('  과부하/고부하 선로 (상위 8):\n');
    for k = ix(1:8)'
        fprintf('    %-8s - %-8s (%3d kV) : %7.0f MW, 부하율 %5.1f %%\n', c.name_kr{c.f(k)}, ...
            c.name_kr{c.t(k)}, c.br_kv(k), real(fl.Sij(k)) * Sb, lp(k));
    end

    % CSV
    fid = fopen(fullfile(outdir, [tag '_bus.csv']), 'w');
    fprintf(fid, 'bus,name,area,kV,type,V_pu,V_kV,angle_deg,Pd_MW,Pg_MW\n');
    for k = 1:c.nb
        fprintf(fid, '%d,%s,%s,%d,%d,%.5f,%.2f,%.4f,%.2f,%.2f\n', k, c.name{k}, c.area_name{c.area(k)}, ...
            c.kv(k), c.type(k), res.V(k), res.V(k)*c.kv(k), res.th_deg(k), c.Pd(k), Pg_bus(k));
    end
    fclose(fid);
    fid = fopen(fullfile(outdir, [tag '_line.csv']), 'w');
    fprintf(fid, 'line,from,to,from_name,to_name,kV,P_MW,Q_MVar,S_MVA,rate_MVA,loading_pct,Ploss_MW\n');
    for k = 1:numel(c.f)
        fprintf(fid, '%d,%d,%d,%s,%s,%d,%.2f,%.2f,%.2f,%.0f,%.2f,%.3f\n', k, c.f(k), c.t(k), c.name{c.f(k)}, ...
            c.name{c.t(k)}, c.br_kv(k), real(fl.Sij(k))*Sb, imag(fl.Sij(k))*Sb, fl.Smax(k)*Sb, ...
            c.rate(k)*Sb, lp(k), real(fl.loss(k))*Sb);
    end
    fclose(fid);
    plot_kpg(c, res, lp, label, fullfile(outdir, [tag '.png']));
end

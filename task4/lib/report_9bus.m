function out = report_9bus(c, res, title_str, outdir, tag)
% REPORT_9BUS  9모선 조류계산 결과를 실제 단위로 변환·출력하고 그림 저장
%   전압 [kV], 전력 [GW / GVar], 임피던스 [Ohm]
    Sb = c.baseMVA / 1000;               % 30 GVA
    Vb = c.baseKV;                       % 345 kV
    Zb = Vb^2 / c.baseMVA;               % 345^2/30000 = 3.9675 Ohm
    Vmin = 0.95; Vmax = 1.05;            % 345kV 운전범위 328~362 kV (약 ±5%)

    Ybus = make_ybus(c.nb, c.f, c.t, c.r, c.x, c.b);
    fl = branch_flows(res.V, res.th, c.f, c.t, c.r, c.x, c.b);
    PG = res.P + c.PL;  QG = res.Q + c.QL;     % 발전기 출력 = 주입 + 부하

    fprintf('\n===== %s =====\n', title_str);
    fprintf('Bus Region       Type  |V|[pu]  |V|[kV]  ang[deg]   Pinj[GW]  Qinj[GVar]  Check\n');
    tn = {'Slack','PV','PQ'};
    viol = false(c.nb, 1);
    for k = 1:c.nb
        s = 'OK';
        if res.V(k) < Vmin - 1e-9, s = 'LOW V'; viol(k) = true; end
        if res.V(k) > Vmax + 1e-9, s = 'HIGH V'; viol(k) = true; end
        fprintf('%3d %-11s %-5s %7.4f  %7.1f  %8.3f  %9.3f  %9.3f   %s\n', k, c.name{k}, ...
            tn{c.type(k)}, res.V(k), res.V(k)*Vb, res.th_deg(k), res.P(k)*Sb, res.Q(k)*Sb, s);
    end
    fprintf('Slack(bus %d) 발전: P = %.3f GW, Q = %.3f GVar\n', find(c.type==1), ...
        PG(c.type==1)*Sb, QG(c.type==1)*Sb);

    fprintf('\nLine   From->To    R[Ohm]   X[Ohm]   P_ij[GW]  Q_ij[GVar]  |S|[GVA]  Load[%%]  Ploss[MW]  Qloss[MVar]\n');
    nl = numel(c.f);
    load_pct = fl.Smax ./ c.rate * 100;
    for k = 1:nl
        fprintf('%3d   %2d -> %-2d  %8.3f %8.3f  %9.3f  %9.3f  %8.3f  %7.1f  %9.1f  %10.1f\n', k, c.f(k), c.t(k), ...
            c.r(k)*Zb, c.x(k)*Zb, real(fl.Sij(k))*Sb, imag(fl.Sij(k))*Sb, fl.Smax(k)*Sb, ...
            load_pct(k), real(fl.loss(k))*Sb*1000, imag(fl.loss(k))*Sb*1000);
    end
    fprintf('총 유효전력 손실 = %.1f MW (%.2f %% of load)\n', sum(real(fl.loss))*Sb*1000, ...
        sum(real(fl.loss)) / sum(c.PL(c.PL>0)) * 100);
    fprintf('최대 선로 부하율 = %.1f %% (line %d-%d)\n', max(load_pct), ...
        c.f(load_pct==max(load_pct)), c.t(load_pct==max(load_pct)));
    if any(viol)
        fprintf('전압 위반 모선: %s\n', mat2str(find(viol)'));
    else
        fprintf('전압 위반 모선 없음\n');
    end

    out.fl = fl; out.load_pct = load_pct; out.viol = viol; out.PG = PG; out.QG = QG;
    out.loss_MW = sum(real(fl.loss))*Sb*1000;

    % ---- CSV 저장 ----
    fid = fopen(fullfile(outdir, [tag '_bus.csv']), 'w');
    fprintf(fid, 'bus,region,type,V_pu,V_kV,angle_deg,Pinj_GW,Qinj_GVar\n');
    for k = 1:c.nb
        fprintf(fid, '%d,%s,%d,%.5f,%.2f,%.4f,%.4f,%.4f\n', k, c.name{k}, c.type(k), ...
            res.V(k), res.V(k)*Vb, res.th_deg(k), res.P(k)*Sb, res.Q(k)*Sb);
    end
    fclose(fid);
    fid = fopen(fullfile(outdir, [tag '_line.csv']), 'w');
    fprintf(fid, 'line,from,to,R_ohm,X_ohm,Pij_GW,Qij_GVar,S_GVA,loading_pct,Ploss_MW,Qloss_MVar\n');
    for k = 1:nl
        fprintf(fid, '%d,%d,%d,%.4f,%.4f,%.4f,%.4f,%.4f,%.2f,%.2f,%.2f\n', k, c.f(k), c.t(k), ...
            c.r(k)*Zb, c.x(k)*Zb, real(fl.Sij(k))*Sb, imag(fl.Sij(k))*Sb, fl.Smax(k)*Sb, ...
            load_pct(k), real(fl.loss(k))*Sb*1000, imag(fl.loss(k))*Sb*1000);
    end
    fclose(fid);

    % ---- 그림 ----
    plot_9bus(c, res, load_pct, fl, title_str, fullfile(outdir, [tag '.png']));
end

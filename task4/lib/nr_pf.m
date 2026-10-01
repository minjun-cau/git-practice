function res = nr_pf(Ybus, type, Psp, Qsp, V0, th0, opts)
% NR_PF  Newton-Raphson 조류계산 (극좌표형, Bergen Ch.10)
%
%   type : 1 = Slack, 2 = PV, 3 = PQ        (9모선 데이터와 같은 번호 체계)
%   Psp, Qsp : 지정 순주입전력 [pu] (발전 - 부하)
%   V0, th0  : 초기 전압크기 [pu], 위상각 [rad]
%   opts.tol (기본 1e-8), opts.maxit (기본 20), opts.verbose
%
%   미지수   x  = [ th(PV,PQ) ; V(PQ) ]
%   불일치   f  = [ dP(PV,PQ) ; dQ(PQ) ]
%   자코비안 J  = [ dP/dth  dP/dV ; dQ/dth  dQ/dV ]   ->  dx = J \ f
%
%   ※ 각도는 반드시 '라디안'으로 계산해야 함.
%     자코비안의 dP/dth 는 th 가 라디안일 때의 미분이므로,
%     도(degree) 단위로 업데이트하면 수렴이 매우 느려지거나 발산함.

    if nargin < 7, opts = struct(); end
    tol   = getopt(opts, 'tol', 1e-8);
    maxit = getopt(opts, 'maxit', 20);
    verb  = getopt(opts, 'verbose', false);

    n   = numel(type);
    V   = V0(:);  th = th0(:);
    pv  = find(type == 2);
    pq  = find(type == 3);
    pvpq = [pv; pq];
    npvpq = numel(pvpq);

    hist = zeros(maxit+1, 1);
    converged = false;

    for it = 0:maxit
        [P, Q] = calc_power(Ybus, V, th);
        dP = Psp(:) - P;
        dQ = Qsp(:) - Q;
        f  = [dP(pvpq); dQ(pq)];
        hist(it+1) = max(abs(f));
        if verb
            fprintf('  iter %2d : max mismatch = %.3e\n', it, hist(it+1));
        end
        if hist(it+1) < tol
            converged = true;
            break;
        end
        if it == maxit, break; end

        % ---- 자코비안 (행렬식으로 한 번에 계산) ----
        %  Vc = V e^{j th},  I = Ybus Vc
        %  dS/dth = j diag(Vc) conj(diag(I) - Ybus diag(Vc))
        %  dS/dV  = diag(Vc) conj(Ybus diag(Vc./V)) + diag(Vc./V) conj(diag(I))
        Vc  = V .* exp(1j*th);
        I   = Ybus * Vc;
        dVc = sparse(1:n, 1:n, Vc, n, n);
        dI  = sparse(1:n, 1:n, I,  n, n);
        dVn = sparse(1:n, 1:n, Vc ./ V, n, n);
        dS_dth = 1j * dVc * conj(dI - Ybus * dVc);
        dS_dV  = dVc * conj(Ybus * dVn) + dVn * conj(dI);

        J11 = real(dS_dth(pvpq, pvpq));  J12 = real(dS_dV(pvpq, pq));
        J21 = imag(dS_dth(pq,   pvpq));  J22 = imag(dS_dV(pq,   pq));
        J = [J11 J12; J21 J22];

        dx = J \ f;
        th(pvpq) = th(pvpq) + dx(1:npvpq);
        V(pq)    = V(pq)    + dx(npvpq+1:end);
    end

    [P, Q] = calc_power(Ybus, V, th);
    res.V = V;  res.th = th;  res.th_deg = th * 180/pi;
    res.P = P;  res.Q = Q;
    res.iter = it;  res.converged = converged;
    res.mismatch = hist(1:it+1);
end

function v = getopt(s, name, default)
    if isfield(s, name), v = s.(name); else, v = default; end
end

function res = gs_pf(Ybus, type, Psp, Qsp, V0, th0, opts)
% GS_PF  Gauss-Seidel 조류계산 (Bergen Ch.10)
%
%   PQ 모선 : V_i <- (1/Y_ii) [ (P_i - jQ_i)/conj(V_i) - sum_{k~=i} Y_ik V_k ]
%   PV 모선 : Q_i 를 현재 전압으로 계산 -> 위 식으로 각도만 갱신, |V_i| 는 지정값 유지
%   opts.alpha : 가속계수 (기본 1.0, 1.4~1.6 이면 보통 빨라짐)

    if nargin < 7, opts = struct(); end
    tol   = getopt(opts, 'tol', 1e-8);
    maxit = getopt(opts, 'maxit', 5000);
    alpha = getopt(opts, 'alpha', 1.0);

    n  = numel(type);
    Vc = V0(:) .* exp(1j*th0(:));
    Vsp = V0(:);
    Q = Qsp(:);
    hist = zeros(maxit+1, 1);
    converged = false;

    for it = 0:maxit
        % 수렴 판정은 NR 과 동일하게 전력 불일치(mismatch)로 함
        S = Vc .* conj(Ybus * Vc);
        dP = Psp(:) - real(S);  dQ = Qsp(:) - imag(S);
        f = [dP(type ~= 1); dQ(type == 3)];
        hist(it+1) = max(abs(f));
        if hist(it+1) < tol, converged = true; break; end
        if it == maxit, break; end

        for i = 1:n
            if type(i) == 1, continue; end
            Yrow = Ybus(i, :);
            sumYV = Yrow * Vc - Ybus(i,i) * Vc(i);
            if type(i) == 2
                Q(i) = -imag(conj(Vc(i)) * (Yrow * Vc));   % Q 계산
            end
            Vnew = ((Psp(i) - 1j*Q(i)) / conj(Vc(i)) - sumYV) / Ybus(i,i);
            if type(i) == 2
                Vc(i) = Vsp(i) * exp(1j*angle(Vnew));       % 크기 고정
            else
                Vc(i) = Vc(i) + alpha * (Vnew - Vc(i));     % 가속
            end
        end
    end

    res.V = abs(Vc);  res.th = angle(Vc);  res.th_deg = res.th * 180/pi;
    [res.P, res.Q] = calc_power(Ybus, res.V, res.th);
    res.iter = it;  res.converged = converged;
    res.mismatch = hist(1:it+1);
end

function v = getopt(s, name, default)
    if isfield(s, name), v = s.(name); else, v = default; end
end

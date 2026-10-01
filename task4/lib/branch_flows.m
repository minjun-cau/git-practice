function fl = branch_flows(V, th, fbus, tbus, r, x, b)
% BRANCH_FLOWS  선로 조류 및 손실 [pu]
%   I_ij = y (V_i - V_j) + (jb/2) V_i ,   S_ij = V_i conj(I_ij)
%   손실 = S_ij + S_ji
    Vc = V(:) .* exp(1j*th(:));
    y  = 1 ./ (r(:) + 1j*x(:));
    ysh = 1j * b(:) / 2;
    Vi = Vc(fbus(:));  Vj = Vc(tbus(:));
    Iij = y .* (Vi - Vj) + ysh .* Vi;
    Iji = y .* (Vj - Vi) + ysh .* Vj;
    fl.Sij  = Vi .* conj(Iij);
    fl.Sji  = Vj .* conj(Iji);
    fl.loss = fl.Sij + fl.Sji;               % P: 저항 손실, Q: 리액턴스 소비 - 충전
    fl.Smax = max(abs(fl.Sij), abs(fl.Sji)); % 부하율 계산용 피상전력
end

function [P, Q] = calc_power(Ybus, V, th)
% CALC_POWER  모선 주입전력 계산  S = V .* conj(Ybus*V)
%   P_i = sum_k |V_i||V_k| ( G_ik cos(th_i-th_k) + B_ik sin(th_i-th_k) )
%   Q_i = sum_k |V_i||V_k| ( G_ik sin(th_i-th_k) - B_ik cos(th_i-th_k) )
%   th 는 라디안 단위
    Vc = V(:) .* exp(1j*th(:));
    S  = Vc .* conj(Ybus * Vc);
    P  = real(S);
    Q  = imag(S);
end

function c = add_hvdc(c, from_bus, to_bus, P, loss_rate, Vset_from, Vset_to)
% ADD_HVDC  HVDC 를 조류계산에 넣는 간단 모델 (정상상태)
%   송전단: P 만큼 부하처럼 빼고, 수전단: P*(1-loss_rate) 만큼 발전기처럼 주입
%   VSC-HVDC 이면 변환소가 무효전력을 독립 제어 → 해당 모선을 PV 모선(전압 지정)으로 둠
    c.Psp(from_bus) = c.Psp(from_bus) - P;
    c.Psp(to_bus)   = c.Psp(to_bus)   + P * (1 - loss_rate);
    if nargin >= 6 && ~isempty(Vset_from)
        c.type(from_bus) = 2;  c.V0(from_bus) = Vset_from;
    end
    if nargin >= 7 && ~isempty(Vset_to)
        c.type(to_bus) = 2;  c.V0(to_bus) = Vset_to;
    end
end

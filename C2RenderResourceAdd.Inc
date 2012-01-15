  Result := High(Elements);
  while (Result >= 0) and not IsEmpty(Elements[Result]) do Dec(Result);

  if Result < 0 then begin                                             // No free slot
    SetLength(Elements, Length(Elements)+1);
    Result := High(Elements);
  end;